defmodule TantivyEx.Distributed.Coordinator do
  @moduledoc """
  Central coordinator for distributed search operations.

  This GenServer manages the overall distributed search configuration,
  orchestrates searches across multiple nodes, and handles failover.
  """

  use GenServer
  require Logger

  alias TantivyEx.Distributed.SearchNode

  @type config :: %{
          timeout_ms: non_neg_integer(),
          max_retries: non_neg_integer(),
          merge_strategy: merge_strategy(),
          load_balancing: load_balancing_strategy(),
          health_check_interval: non_neg_integer()
        }

  @type merge_strategy :: :score_desc | :score_asc | :node_order | :round_robin
  @type load_balancing_strategy ::
          :round_robin | :weighted_round_robin | :least_connections | :health_based

  defstruct [
    :registry,
    :config,
    :node_round_robin_counter,
    :cluster_stats
  ]

  ## Client API

  @doc """
  Start the coordinator GenServer.
  """
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    registry = Keyword.fetch!(opts, :registry)
    GenServer.start_link(__MODULE__, %{registry: registry}, name: name)
  end

  @doc """
  Add a search node to the cluster.
  """
  @spec add_node(GenServer.server(), String.t(), String.t(), float()) ::
          :ok | {:error, term()}
  def add_node(coordinator, node_id, endpoint, weight) when weight > 0.0 do
    GenServer.call(coordinator, {:add_node, node_id, endpoint, weight})
  end

  @doc """
  Remove a search node from the cluster.
  """
  @spec remove_node(GenServer.server(), String.t()) :: :ok | {:error, term()}
  def remove_node(coordinator, node_id) do
    GenServer.call(coordinator, {:remove_node, node_id})
  end

  @doc """
  Configure the distributed search behavior.
  """
  @spec configure(GenServer.server(), config()) :: :ok | {:error, term()}
  def configure(coordinator, config) do
    GenServer.call(coordinator, {:configure, config})
  end

  @doc """
  Perform a distributed search across all active nodes.
  """
  @spec search(GenServer.server(), term(), non_neg_integer(), non_neg_integer()) ::
          {:ok, map()} | {:error, term()}
  def search(coordinator, query, limit, offset) do
    GenServer.call(coordinator, {:search, query, limit, offset}, 30_000)
  end

  @doc """
  Get cluster statistics.
  """
  @spec get_cluster_stats(GenServer.server()) :: {:ok, map()}
  def get_cluster_stats(coordinator) do
    GenServer.call(coordinator, :get_cluster_stats)
  end

  @doc """
  Get list of active nodes.
  """
  @spec get_active_nodes(GenServer.server()) :: {:ok, [String.t()]}
  def get_active_nodes(coordinator) do
    GenServer.call(coordinator, :get_active_nodes)
  end

  @doc """
  Set node active/inactive status.
  """
  @spec set_node_status(GenServer.server(), String.t(), boolean()) :: :ok | {:error, term()}
  def set_node_status(coordinator, node_id, active) do
    GenServer.call(coordinator, {:set_node_status, node_id, active})
  end

  ## GenServer Implementation

  @impl true
  def init(%{registry: registry}) do
    # Schedule periodic health checks
    Process.send_after(self(), :health_check, 5_000)

    state = %__MODULE__{
      registry: registry,
      config: default_config(),
      node_round_robin_counter: 0,
      cluster_stats: %{
        total_searches: 0,
        successful_searches: 0,
        failed_searches: 0,
        average_response_time: 0.0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:add_node, node_id, endpoint, weight}, _from, state) do
    case start_search_node(node_id, endpoint, weight, state.registry) do
      {:ok, _pid} ->
        Logger.info("Added search node: #{node_id} at #{endpoint} with weight #{weight}")
        {:reply, :ok, state}

      {:error, reason} ->
        Logger.error("Failed to add search node #{node_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:remove_node, node_id}, _from, state) do
    case Registry.lookup(state.registry, node_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(TantivyEx.Distributed.NodeSupervisor, pid)
        Logger.info("Removed search node: #{node_id}")
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :node_not_found}, state}
    end
  end

  @impl true
  def handle_call({:configure, config}, _from, state) do
    new_config = Map.merge(state.config, config)
    {:reply, :ok, %{state | config: new_config}}
  end

  @impl true
  def handle_call({:search, query, limit, offset}, from, state) do
    # Perform async distributed search
    task =
      Task.Supervisor.async_nolink(TantivyEx.Distributed.TaskSupervisor, fn ->
        perform_distributed_search(query, limit, offset, state)
      end)

    # Store the task reference to handle the response
    {:noreply, state, {:continue, {:await_search, task, from}}}
  end

  @impl true
  def handle_call(:get_cluster_stats, _from, state) do
    nodes = get_all_nodes(state.registry)
    active_nodes = get_active_node_pids(state.registry)

    stats = %{
      total_nodes: length(nodes),
      active_nodes: length(active_nodes),
      inactive_nodes: length(nodes) - length(active_nodes),
      config: state.config,
      cluster_stats: state.cluster_stats
    }

    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_call(:get_active_nodes, _from, state) do
    active_nodes =
      get_active_node_pids(state.registry)
      |> Enum.map(fn {node_id, _pid} -> node_id end)

    {:reply, {:ok, active_nodes}, state}
  end

  @impl true
  def handle_call({:set_node_status, node_id, active}, _from, state) do
    case Registry.lookup(state.registry, node_id) do
      [{pid, _}] ->
        SearchNode.set_active(pid, active)
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :node_not_found}, state}
    end
  end

  @impl true
  def handle_continue({:await_search, task, from}, state) do
    case Task.yield(task, state.config.timeout_ms) do
      {:ok, result} ->
        GenServer.reply(from, result)
        updated_stats = update_search_stats(state.cluster_stats, result)
        {:noreply, %{state | cluster_stats: updated_stats}}

      nil ->
        Task.shutdown(task)
        GenServer.reply(from, {:error, :timeout})
        updated_stats = update_search_stats(state.cluster_stats, {:error, :timeout})
        {:noreply, %{state | cluster_stats: updated_stats}}

      {:exit, reason} ->
        GenServer.reply(from, {:error, {:task_exit, reason}})
        updated_stats = update_search_stats(state.cluster_stats, {:error, reason})
        {:noreply, %{state | cluster_stats: updated_stats}}
    end
  end

  @impl true
  def handle_info(:health_check, state) do
    # Perform health checks on all nodes
    perform_health_checks(state.registry)

    # Schedule next health check
    interval = state.config.health_check_interval
    Process.send_after(self(), :health_check, interval)

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Node process went down - will be handled by supervisor
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Private Functions

  defp default_config do
    %{
      timeout_ms: 5_000,
      max_retries: 3,
      merge_strategy: :score_desc,
      load_balancing: :weighted_round_robin,
      health_check_interval: 30_000
    }
  end

  defp start_search_node(node_id, endpoint, weight, registry) do
    child_spec =
      {SearchNode, node_id: node_id, endpoint: endpoint, weight: weight, registry: registry}

    DynamicSupervisor.start_child(TantivyEx.Distributed.NodeSupervisor, child_spec)
  end

  defp perform_distributed_search(query, limit, offset, state) do
    start_time = :os.system_time(:millisecond)

    active_nodes = get_active_node_pids(state.registry)

    if Enum.empty?(active_nodes) do
      {:error, :no_active_nodes}
    else
      # Execute search on all active nodes concurrently
      search_tasks =
        Enum.map(active_nodes, fn {node_id, pid} ->
          Task.Supervisor.async_nolink(TantivyEx.Distributed.TaskSupervisor, fn ->
            SearchNode.search(pid, query, limit, offset)
            |> case do
              {:ok, results} -> {node_id, {:ok, results}}
              error -> {node_id, error}
            end
          end)
        end)

      # Collect results with timeout
      node_results =
        search_tasks
        |> Task.yield_many(state.config.timeout_ms)
        |> Enum.map(fn
          {_task, {:ok, result}} ->
            result

          {task, nil} ->
            Task.shutdown(task)
            {"unknown", {:error, :timeout}}

          {_task, {:exit, reason}} ->
            {"unknown", {:error, {:task_exit, reason}}}
        end)

      # Merge and return results
      merge_search_results(node_results, state.config.merge_strategy, start_time)
    end
  end

  defp merge_search_results(node_results, merge_strategy, start_time) do
    took_ms = :os.system_time(:millisecond) - start_time

    {successful_results, errors} =
      Enum.split_with(node_results, fn {_node_id, result} ->
        match?({:ok, _}, result)
      end)

    if Enum.empty?(successful_results) do
      {:error,
       %{
         errors:
           Enum.map(errors, fn {node_id, {:error, reason}} ->
             "#{node_id}: #{inspect(reason)}"
           end)
       }}
    else
      # Extract hits from successful results
      all_hits =
        successful_results
        |> Enum.flat_map(fn {_node_id, {:ok, results}} ->
          Map.get(results, :hits, [])
        end)

      # Apply merge strategy
      merged_hits = apply_merge_strategy(all_hits, merge_strategy)

      total_hits =
        successful_results
        |> Enum.map(fn {_node_id, {:ok, results}} ->
          Map.get(results, :total_hits, 0)
        end)
        |> Enum.sum()

      error_list =
        errors
        |> Enum.map(fn {node_id, {:error, reason}} ->
          "#{node_id}: #{inspect(reason)}"
        end)

      response = %{
        total_hits: total_hits,
        hits: merged_hits,
        node_responses: format_node_responses(node_results),
        took_ms: took_ms,
        errors: error_list
      }

      {:ok, response}
    end
  end

  defp apply_merge_strategy(hits, :score_desc) do
    Enum.sort_by(hits, & &1.score, :desc)
  end

  defp apply_merge_strategy(hits, :score_asc) do
    Enum.sort_by(hits, & &1.score, :asc)
  end

  defp apply_merge_strategy(hits, :node_order) do
    hits
  end

  defp apply_merge_strategy(hits, :round_robin) do
    # Simple round-robin interleaving
    hits
    |> Enum.with_index()
    |> Enum.sort_by(fn {_hit, index} -> index end)
    |> Enum.map(fn {hit, _index} -> hit end)
  end

  defp format_node_responses(node_results) do
    Enum.map(node_results, fn
      {node_id, {:ok, results}} ->
        %{
          node_id: node_id,
          total_hits: Map.get(results, :total_hits, 0),
          hits: Map.get(results, :hits, []),
          took_ms: Map.get(results, :took_ms, 0),
          error: nil
        }

      {node_id, {:error, reason}} ->
        %{
          node_id: node_id,
          total_hits: 0,
          hits: [],
          took_ms: 0,
          error: inspect(reason)
        }
    end)
  end

  defp get_all_nodes(registry) do
    Registry.select(registry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])
  end

  defp get_active_node_pids(registry) do
    registry
    |> get_all_nodes()
    |> Enum.filter(fn {_node_id, pid} ->
      try do
        Process.alive?(pid) && SearchNode.is_active?(pid)
      rescue
        _ -> false
      catch
        :exit, _ -> false
      end
    end)
  end

  defp perform_health_checks(registry) do
    get_all_nodes(registry)
    |> Enum.each(fn {_node_id, pid} ->
      SearchNode.health_check(pid)
    end)
  end

  defp update_search_stats(current_stats, search_result) do
    total_searches = current_stats.total_searches + 1

    case search_result do
      {:ok, %{took_ms: took_ms}} ->
        successful = current_stats.successful_searches + 1

        # Update average response time
        avg_response_time =
          (current_stats.average_response_time * current_stats.successful_searches + took_ms) /
            successful

        %{
          total_searches: total_searches,
          successful_searches: successful,
          failed_searches: current_stats.failed_searches,
          average_response_time: avg_response_time
        }

      {:error, _} ->
        %{
          current_stats
          | total_searches: total_searches,
            failed_searches: current_stats.failed_searches + 1
        }
    end
  end
end
