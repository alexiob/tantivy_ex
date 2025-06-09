defmodule TantivyEx.Distributed.OTP do
  @moduledoc """
  OTP-based distributed search API for TantivyEx.

  This module provides a clean, OTP-native interface for distributed search
  operations, leveraging Elixir's supervision trees, GenServers, and fault
  tolerance mechanisms instead of native coordination.

  ## Features

  - Supervisor-based fault tolerance
  - GenServer per search node
  - Registry-based node discovery
  - Task supervision for concurrent operations
  - Built-in health monitoring
  - Automatic failover and recovery

  ## Example Usage

      # Start the distributed search system
      {:ok, _pid} = TantivyEx.Distributed.OTP.start_link()

      # Add search nodes
      :ok = TantivyEx.Distributed.OTP.add_node("node1", "local://index1", 1.0)
      :ok = TantivyEx.Distributed.OTP.add_node("node2", "local://index2", 1.5)

      # Configure behavior
      :ok = TantivyEx.Distributed.OTP.configure(%{
        timeout_ms: 5000,
        merge_strategy: :score_desc
      })

      # Perform distributed search
      {:ok, results} = TantivyEx.Distributed.OTP.search("query text", 10, 0)
  """

  alias TantivyEx.Distributed.{Supervisor, Coordinator}

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

  @coordinator_name TantivyEx.Distributed.Coordinator
  @registry_name TantivyEx.Distributed.Registry

  ## Public API

  @doc """
  Start the distributed search system.

  This starts the supervision tree and all necessary processes.

  ## Options

  - `:name` - Name for the main supervisor (default: TantivyEx.Distributed.Supervisor)
  - `:coordinator_name` - Name for the coordinator GenServer
  - `:registry_name` - Name for the node registry

  ## Examples

      {:ok, pid} = TantivyEx.Distributed.OTP.start_link()
      {:ok, pid} = TantivyEx.Distributed.OTP.start_link(name: MyApp.DistributedSearch)
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    coordinator_name = Keyword.get(opts, :coordinator_name, @coordinator_name)
    registry_name = Keyword.get(opts, :registry_name, @registry_name)

    supervisor_opts = [
      coordinator_name: coordinator_name,
      registry_name: registry_name
    ]

    Supervisor.start_link(supervisor_opts)
  end

  @doc """
  Add a search node to the distributed cluster.

  ## Parameters

  - `node_id` - Unique identifier for the node
  - `endpoint` - Endpoint specification (e.g., "local://path", "http://host:port")
  - `weight` - Weight for load balancing (must be > 0.0)
  - `opts` - Additional options

  ## Examples

      :ok = TantivyEx.Distributed.OTP.add_node("node1", "local://index1", 1.0)
      :ok = TantivyEx.Distributed.OTP.add_node("node2", "http://remote:9200", 2.0)
  """
  @spec add_node(String.t(), String.t(), float(), keyword()) :: :ok | {:error, term()}
  def add_node(node_id, endpoint, weight, opts \\ []) do
    coordinator = Keyword.get(opts, :coordinator, @coordinator_name)
    Coordinator.add_node(coordinator, node_id, endpoint, weight)
  end

  @doc """
  Remove a search node from the cluster.

  ## Parameters

  - `node_id` - Unique identifier for the node to remove
  - `opts` - Additional options

  ## Examples

      :ok = TantivyEx.Distributed.OTP.remove_node("node1")
  """
  @spec remove_node(String.t(), keyword()) :: :ok | {:error, term()}
  def remove_node(node_id, opts \\ []) do
    coordinator = Keyword.get(opts, :coordinator, @coordinator_name)
    Coordinator.remove_node(coordinator, node_id)
  end

  @doc """
  Configure the distributed search behavior.

  ## Configuration Options

  - `:timeout_ms` - Request timeout in milliseconds (default: 5000)
  - `:max_retries` - Maximum retries for failed requests (default: 3)
  - `:merge_strategy` - Result merging strategy (default: :score_desc)
  - `:load_balancing` - Load balancing strategy (default: :weighted_round_robin)
  - `:health_check_interval` - Health check interval in ms (default: 30000)

  ## Examples

      :ok = TantivyEx.Distributed.OTP.configure(%{
        timeout_ms: 10_000,
        merge_strategy: :score_desc,
        health_check_interval: 60_000
      })
  """
  @spec configure(config(), keyword()) :: :ok | {:error, term()}
  def configure(config, opts \\ []) do
    coordinator = Keyword.get(opts, :coordinator, @coordinator_name)
    Coordinator.configure(coordinator, config)
  end

  @doc """
  Perform a distributed search across the cluster.

  ## Parameters

  - `query` - Search query (string or compiled query reference)
  - `limit` - Maximum number of results to return
  - `offset` - Number of results to skip for pagination
  - `opts` - Additional options

  ## Examples

      {:ok, results} = TantivyEx.Distributed.OTP.search("rust programming", 20, 0)

      # With options
      {:ok, results} = TantivyEx.Distributed.OTP.search(
        "rust programming",
        20,
        0,
        coordinator: MyApp.Coordinator
      )
  """
  @spec search(String.t() | reference(), non_neg_integer(), non_neg_integer(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def search(query, limit, offset, opts \\ []) do
    coordinator = Keyword.get(opts, :coordinator, @coordinator_name)
    Coordinator.search(coordinator, query, limit, offset)
  end

  @doc """
  Get cluster statistics and health information.

  ## Returns

  A map containing:
  - `:total_nodes` - Total number of configured nodes
  - `:active_nodes` - Number of currently active nodes
  - `:inactive_nodes` - Number of inactive nodes
  - `:config` - Current configuration
  - `:cluster_stats` - Performance statistics

  ## Examples

      {:ok, stats} = TantivyEx.Distributed.OTP.get_cluster_stats()
      IO.puts "Active nodes: \#{stats.active_nodes}/\#{stats.total_nodes}"
  """
  @spec get_cluster_stats(keyword()) :: {:ok, map()}
  def get_cluster_stats(opts \\ []) do
    coordinator = Keyword.get(opts, :coordinator, @coordinator_name)
    Coordinator.get_cluster_stats(coordinator)
  end

  @doc """
  Get list of active node IDs.

  ## Examples

      {:ok, nodes} = TantivyEx.Distributed.OTP.get_active_nodes()
      # => {:ok, ["node1", "node2"]}
  """
  @spec get_active_nodes(keyword()) :: {:ok, [String.t()]}
  def get_active_nodes(opts \\ []) do
    coordinator = Keyword.get(opts, :coordinator, @coordinator_name)
    Coordinator.get_active_nodes(coordinator)
  end

  @doc """
  Set a node's active/inactive status.

  Inactive nodes will not receive search requests.

  ## Parameters

  - `node_id` - Unique identifier for the node
  - `active` - Whether the node should be active
  - `opts` - Additional options

  ## Examples

      :ok = TantivyEx.Distributed.OTP.set_node_status("node1", false)
      :ok = TantivyEx.Distributed.OTP.set_node_status("node1", true)
  """
  @spec set_node_status(String.t(), boolean(), keyword()) :: :ok | {:error, term()}
  def set_node_status(node_id, active, opts \\ []) do
    coordinator = Keyword.get(opts, :coordinator, @coordinator_name)
    Coordinator.set_node_status(coordinator, node_id, active)
  end

  @doc """
  Get detailed statistics for a specific node.

  ## Parameters

  - `node_id` - Unique identifier for the node
  - `opts` - Additional options

  ## Examples

      {:ok, stats} = TantivyEx.Distributed.OTP.get_node_stats("node1")
  """
  @spec get_node_stats(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_node_stats(node_id, opts \\ []) do
    registry = Keyword.get(opts, :registry, @registry_name)

    case Registry.lookup(registry, node_id) do
      [{pid, _}] ->
        TantivyEx.Distributed.SearchNode.get_stats(pid)

      [] ->
        {:error, :node_not_found}
    end
  end

  @doc """
  Check if the distributed search system is running.

  ## Examples

      true = TantivyEx.Distributed.OTP.running?()
  """
  @spec running?(keyword()) :: boolean()
  def running?(opts \\ []) do
    coordinator = Keyword.get(opts, :coordinator, @coordinator_name)

    case Process.whereis(coordinator) do
      nil -> false
      pid when is_pid(pid) -> Process.alive?(pid)
    end
  end

  @doc """
  Stop the distributed search system.

  This will gracefully shut down all nodes and supervisors.

  ## Examples

      :ok = TantivyEx.Distributed.OTP.stop()
  """
  @spec stop(keyword()) :: :ok
  def stop(opts \\ []) do
    supervisor = Keyword.get(opts, :supervisor, TantivyEx.Distributed.Supervisor)
    coordinator = Keyword.get(opts, :coordinator, @coordinator_name)
    timeout = Keyword.get(opts, :timeout, 5000)

    case Process.whereis(supervisor) do
      nil ->
        :ok

      pid ->
        try do
          Process.exit(pid, :normal)

          # Wait for the coordinator to actually terminate
          wait_for_termination(coordinator, timeout)
          :ok
        catch
          :exit, {:noproc, _} -> :ok
          :exit, {:timeout, _} -> :ok
        end
    end
  end

  # Private helper to wait for process termination
  defp wait_for_termination(coordinator, timeout) do
    start_time = System.monotonic_time(:millisecond)

    do_wait_for_termination(coordinator, timeout, start_time)
  end

  defp do_wait_for_termination(coordinator, timeout, start_time) do
    case Process.whereis(coordinator) do
      nil ->
        :ok

      _pid ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        if elapsed >= timeout do
          :ok
        else
          Process.sleep(10)
          do_wait_for_termination(coordinator, timeout, start_time)
        end
    end
  end

  ## Convenience Functions

  @doc """
  Add multiple nodes at once.

  ## Parameters

  - `nodes` - List of `{node_id, endpoint, weight}` tuples
  - `opts` - Additional options

  ## Examples

      nodes = [
        {"node1", "local://index1", 1.0},
        {"node2", "local://index2", 1.5},
        {"node3", "http://remote:9200", 2.0}
      ]

      :ok = TantivyEx.Distributed.OTP.add_nodes(nodes)
  """
  @spec add_nodes([{String.t(), String.t(), float()}], keyword()) :: :ok | {:error, term()}
  def add_nodes(nodes, opts \\ []) when is_list(nodes) do
    results =
      Enum.map(nodes, fn {node_id, endpoint, weight} ->
        add_node(node_id, endpoint, weight, opts)
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  @doc """
  Perform a simple distributed search with sensible defaults.

  This is a convenience function for basic searches.

  ## Examples

      {:ok, results} = TantivyEx.Distributed.OTP.simple_search("rust programming")
  """
  @spec simple_search(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def simple_search(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    offset = Keyword.get(opts, :offset, 0)
    search(query, limit, offset, opts)
  end
end
