defmodule TantivyEx.Distributed.SearchNode do
  @moduledoc """
  GenServer representing a single search node in the distributed cluster.

  Each SearchNode manages its own Tantivy searcher instance and handles
  search requests, health monitoring, and connection management.
  """

  use GenServer
  require Logger

  alias TantivyEx.Searcher

  defstruct [
    :node_id,
    :endpoint,
    :weight,
    :registry,
    :searcher,
    :index,
    :active,
    :health_status,
    :connection_count,
    :total_searches,
    :failed_searches,
    :average_response_time,
    :last_health_check
  ]

  @type health_status :: :healthy | :degraded | :unhealthy | :unknown

  ## Client API

  @doc """
  Start a search node GenServer.
  """
  def start_link(opts) do
    node_id = Keyword.fetch!(opts, :node_id)
    endpoint = Keyword.fetch!(opts, :endpoint)
    weight = Keyword.fetch!(opts, :weight)
    registry = Keyword.fetch!(opts, :registry)

    GenServer.start_link(__MODULE__, %{
      node_id: node_id,
      endpoint: endpoint,
      weight: weight,
      registry: registry
    })
  end

  @doc """
  Perform a search on this node.
  """
  @spec search(pid(), term(), non_neg_integer(), non_neg_integer()) ::
          {:ok, map()} | {:error, term()}
  def search(pid, query, limit, offset) do
    GenServer.call(pid, {:search, query, limit, offset}, 30_000)
  end

  @doc """
  Check if the node is currently active.
  """
  @spec is_active?(pid()) :: boolean()
  def is_active?(pid) do
    GenServer.call(pid, :is_active)
  end

  @doc """
  Set the node's active status.
  """
  @spec set_active(pid(), boolean()) :: :ok
  def set_active(pid, active) do
    GenServer.cast(pid, {:set_active, active})
  end

  @doc """
  Get node statistics.
  """
  @spec get_stats(pid()) :: {:ok, map()}
  def get_stats(pid) do
    GenServer.call(pid, :get_stats)
  end

  @doc """
  Perform a health check on the node.
  """
  @spec health_check(pid()) :: :ok
  def health_check(pid) do
    GenServer.cast(pid, :health_check)
  end

  @doc """
  Get the current health status.
  """
  @spec get_health_status(pid()) :: health_status()
  def get_health_status(pid) do
    GenServer.call(pid, :get_health_status)
  end

  ## GenServer Implementation

  @impl true
  def init(%{node_id: node_id, endpoint: endpoint, weight: weight, registry: registry}) do
    # Register this process in the registry
    {:ok, _} =
      Registry.register(registry, node_id, %{
        endpoint: endpoint,
        weight: weight,
        pid: self()
      })

    # Initialize with a simple in-memory index for demonstration
    # In a real implementation, this might connect to a remote index
    # or manage a local index file
    state = %__MODULE__{
      node_id: node_id,
      endpoint: endpoint,
      weight: weight,
      registry: registry,
      searcher: nil,
      index: nil,
      active: true,
      health_status: :unknown,
      connection_count: 0,
      total_searches: 0,
      failed_searches: 0,
      average_response_time: 0.0,
      last_health_check: nil
    }

    # Initialize the search index asynchronously
    {:ok, state, {:continue, :initialize_index}}
  end

  @impl true
  def handle_continue(:initialize_index, state) do
    case initialize_search_index(state.endpoint) do
      {:ok, index, searcher} ->
        Logger.info("Initialized search node #{state.node_id} at #{state.endpoint}")

        new_state = %{
          state
          | index: index,
            searcher: searcher,
            health_status: :healthy,
            last_health_check: :os.system_time(:millisecond)
        }

        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to initialize search node #{state.node_id}: #{inspect(reason)}")

        new_state = %{
          state
          | health_status: :unhealthy,
            active: false,
            last_health_check: :os.system_time(:millisecond)
        }

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_call({:search, query, limit, offset}, _from, state) do
    if state.active and state.searcher do
      start_time = :os.system_time(:millisecond)

      result = perform_search(state.searcher, query, limit, offset)

      took_ms = :os.system_time(:millisecond) - start_time
      updated_state = update_search_stats(state, result, took_ms)

      case result do
        {:ok, search_results} ->
          response = %{
            total_hits: Map.get(search_results, :total_hits, 0),
            hits: Map.get(search_results, :hits, []),
            took_ms: took_ms,
            node_id: state.node_id
          }

          {:reply, {:ok, response}, updated_state}

        error ->
          {:reply, error, updated_state}
      end
    else
      {:reply, {:error, :node_inactive}, state}
    end
  end

  @impl true
  def handle_call(:is_active, _from, state) do
    {:reply, state.active, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      node_id: state.node_id,
      endpoint: state.endpoint,
      weight: state.weight,
      active: state.active,
      health_status: state.health_status,
      connection_count: state.connection_count,
      total_searches: state.total_searches,
      failed_searches: state.failed_searches,
      average_response_time: state.average_response_time,
      last_health_check: state.last_health_check
    }

    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_call(:get_health_status, _from, state) do
    {:reply, state.health_status, state}
  end

  @impl true
  def handle_cast({:set_active, active}, state) do
    Logger.info("Setting node #{state.node_id} active status to #{active}")
    {:noreply, %{state | active: active}}
  end

  @impl true
  def handle_cast(:health_check, state) do
    new_health_status = perform_health_check(state.searcher)

    updated_state = %{
      state
      | health_status: new_health_status,
        last_health_check: :os.system_time(:millisecond)
    }

    # Automatically deactivate unhealthy nodes
    updated_state =
      case new_health_status do
        :unhealthy -> %{updated_state | active: false}
        :healthy -> %{updated_state | active: true}
        _ -> updated_state
      end

    {:noreply, updated_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Search node #{state.node_id} terminating: #{inspect(reason)}")

    # Clean up resources
    if state.searcher do
      # Note: In a real implementation, you might need to properly close the searcher
      # TantivyEx.Searcher.close(state.searcher)
    end

    :ok
  end

  ## Private Functions

  defp initialize_search_index(_endpoint) do
    # In a real implementation, this would either:
    # 1. Connect to a remote Tantivy service at the endpoint
    # 2. Initialize a local index based on the endpoint configuration
    # 3. Load an existing index from disk

    # For demonstration, we'll create a simple in-memory index
    # In practice, you'd parse the endpoint to determine the connection method

    case create_demo_index() do
      {:ok, index} ->
        case TantivyEx.Searcher.new(index) do
          {:ok, searcher} -> {:ok, index, searcher}
          error -> error
        end

      error ->
        error
    end
  end

  defp create_demo_index do
    # Create a minimal demo index for testing using proper Schema builder pattern
    # In production, this would connect to actual data

    # Build schema using proper TantivyEx API
    schema =
      TantivyEx.Schema.new()
      |> TantivyEx.Schema.add_text_field("title", :text_stored)
      |> TantivyEx.Schema.add_text_field("body", :text_stored)

    case TantivyEx.Index.create_in_ram(schema) do
      {:ok, index} ->
        # Create writer and add demo documents
        case TantivyEx.IndexWriter.new(index, 50_000_000) do
          {:ok, writer} ->
            # Add some demo documents using proper document format
            docs = [
              %{
                "title" => "First Document",
                "body" => "This is the content of the first document"
              },
              %{"title" => "Second Document", "body" => "This contains different content"},
              %{"title" => "Third Document", "body" => "Yet another piece of content"}
            ]

            # Add documents one by one
            case add_documents_to_writer(writer, docs, schema) do
              :ok ->
                case TantivyEx.IndexWriter.commit(writer) do
                  :ok -> {:ok, index}
                  error -> error
                end

              error ->
                error
            end

          error ->
            error
        end

      error ->
        error
    end
  end

  defp add_documents_to_writer(writer, docs, _schema) do
    # Add documents using proper TantivyEx Document API
    Enum.reduce_while(docs, :ok, fn doc, _acc ->
      case TantivyEx.IndexWriter.add_document(writer, doc) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp perform_search(searcher, query_term, limit, offset) when is_binary(query_term) do
    # Create a simple term query using proper Query API with clean error handling
    with {:ok, parser} <- TantivyEx.Query.parser(searcher, ["title", "body"]),
         {:ok, query} <- TantivyEx.Query.parse(parser, query_term),
         {:ok, results} <- TantivyEx.Searcher.search(searcher, query, limit) do
      # Apply offset manually since TantivyEx search doesn't support offset directly
      paginated_results = results |> Enum.drop(offset) |> Enum.take(limit)
      {:ok, paginated_results}
    end
  end

  defp perform_search(searcher, query, limit, offset) when is_reference(query) do
    # Query is already a compiled query reference
    case Searcher.search(searcher, query, limit, offset) do
      {:ok, results} -> {:ok, results}
      error -> error
    end
  end

  defp perform_search(_searcher, _query, _limit, _offset) do
    {:error, :invalid_query}
  end

  defp perform_health_check(nil), do: :unhealthy

  defp perform_health_check(searcher) do
    # Perform a simple health check by verifying the searcher is valid
    # Since we don't have a simple query creation method, we'll just verify
    # the searcher reference is still alive and valid
    try do
      if is_reference(searcher) do
        :healthy
      else
        :unhealthy
      end
    rescue
      _ -> :unhealthy
    end
  end

  defp update_search_stats(state, search_result, took_ms) do
    total_searches = state.total_searches + 1

    case search_result do
      {:ok, _} ->
        # Update average response time
        new_avg = (state.average_response_time * state.total_searches + took_ms) / total_searches

        %{state | total_searches: total_searches, average_response_time: new_avg}

      {:error, _} ->
        %{state | total_searches: total_searches, failed_searches: state.failed_searches + 1}
    end
  end
end
