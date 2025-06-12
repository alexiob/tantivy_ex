defmodule TantivyEx.ResourceManager do
  @moduledoc """
  Comprehensive resource management and lifecycle control for TantivyEx.

  This module provides proper resource cleanup, lifecycle management, and
  resource pooling to ensure efficient resource usage and prevent resource
  leaks in TantivyEx operations.

  ## Features

  - **Resource Lifecycle Management**: Automatic tracking and cleanup
  - **Resource Pooling**: Efficient reuse of expensive resources
  - **Leak Detection**: Detection and prevention of resource leaks
  - **Graceful Shutdown**: Proper cleanup during system shutdown
  - **Resource Monitoring**: Real-time resource usage tracking
  - **Automatic Cleanup**: Cleanup based on usage patterns and memory pressure

  ## Resource Types

  The system manages several types of resources:

  - **Index Resources**: Index instances and their associated files
  - **Writer Resources**: Index writers with their buffer management
  - **Reader Resources**: Index readers and searchers
  - **Query Resources**: Query parsers and compiled queries
  - **Native Resources**: Native Rust objects and memory allocations
  - **Cache Resources**: Various caches and temporary data

  ## Configuration

      TantivyEx.ResourceManager.configure(%{
        # Resource limits
        max_writers: 10,
        max_readers: 50,
        max_cached_queries: 1000,

        # Cleanup policies
        cleanup_interval_ms: 30_000,
        idle_timeout_ms: 300_000,     # 5 minutes
        force_cleanup_threshold: 0.9, # 90% resource usage

        # Pool configuration
        enable_pooling: true,
        pool_min_size: 2,
        pool_max_size: 10,
        pool_checkout_timeout_ms: 5000,

        # Monitoring
        track_usage: true,
        leak_detection: true,
        usage_logging: true
      })

  ## Usage

      # Start the resource manager
      {:ok, _pid} = TantivyEx.ResourceManager.start_link()

      # Register resources for management
      {:ok, writer} = TantivyEx.IndexWriter.new(index, 50_000_000)
      :ok = TantivyEx.ResourceManager.register(writer, :writer, &IndexWriter.close/1)

      # Use pooled resources
      TantivyEx.ResourceManager.with_pooled_reader(index, fn reader ->
        TantivyEx.Searcher.search(reader, query, 10)
      end)

      # Manual resource management
      {:ok, stats} = TantivyEx.ResourceManager.get_resource_stats()
      :ok = TantivyEx.ResourceManager.cleanup_idle_resources()
      :ok = TantivyEx.ResourceManager.force_cleanup()
  """

  use GenServer
  require Logger
  alias TantivyEx.{Error}

  @default_config %{
    # Resource limits
    max_writers: 10,
    max_readers: 50,
    max_indexes: 20,
    max_cached_queries: 1000,
    max_native_objects: 10000,

    # Cleanup policies
    cleanup_interval_ms: 30_000,
    idle_timeout_ms: 300_000,
    force_cleanup_threshold: 0.9,
    auto_cleanup: true,

    # Pool configuration
    enable_pooling: true,
    pool_min_size: 2,
    pool_max_size: 10,
    pool_checkout_timeout_ms: 5000,
    pool_idle_timeout_ms: 600_000,

    # Monitoring
    track_usage: true,
    leak_detection: true,
    usage_logging: false,
    stats_collection: true
  }

  @type resource_type :: :writer | :reader | :index | :query | :native | :cache
  @type resource_info :: %{
          resource: any(),
          type: resource_type(),
          cleanup_fun: function(),
          created_at: DateTime.t(),
          last_used: DateTime.t(),
          usage_count: non_neg_integer(),
          pool_id: String.t() | nil,
          metadata: map()
        }

  @type resource_stats :: %{
          total_resources: non_neg_integer(),
          by_type: map(),
          pool_stats: map(),
          cleanup_stats: map(),
          memory_usage: map()
        }

  @type pool_config :: %{
          min_size: non_neg_integer(),
          max_size: non_neg_integer(),
          checkout_timeout_ms: non_neg_integer(),
          idle_timeout_ms: non_neg_integer()
        }

  # Client API

  @doc """
  Starts the resource manager.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    config = Keyword.get(opts, :config, %{})

    GenServer.start_link(__MODULE__, config, name: name)
  end

  @doc """
  Configures the resource manager.
  """
  @spec configure(map()) :: :ok | {:error, Error.t()}
  def configure(config) when is_map(config) do
    GenServer.call(__MODULE__, {:configure, config})
  end

  @doc """
  Registers a resource for management.

  ## Parameters

  - `resource` - The resource to manage
  - `type` - The resource type
  - `cleanup_fun` - Function to call for cleanup
  - `metadata` - Optional metadata

  ## Examples

      iex> TantivyEx.ResourceManager.register(writer, :writer, &IndexWriter.close/1)
      :ok
  """
  @spec register(any(), resource_type(), function(), map()) :: :ok | {:error, Error.t()}
  def register(resource, type, cleanup_fun, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:register, resource, type, cleanup_fun, metadata})
  end

  @doc """
  Registers a resource with simplified API for tests.
  """
  @spec register_resource(String.t(), map()) :: :ok | {:error, Error.t()}
  def register_resource(resource_id, resource_data) do
    type = Map.get(resource_data, :type, :generic)
    cleanup_fun = Map.get(resource_data, :cleanup_fun, fn _ -> :ok end)
    metadata = Map.put(resource_data, :id, resource_id)
    register(resource_id, type, cleanup_fun, metadata)
  end

  @doc """
  Unregisters a resource from management.
  """
  @spec unregister(any()) :: :ok
  def unregister(resource) do
    GenServer.call(__MODULE__, {:unregister, resource})
  end

  @doc """
  Unregisters a resource by ID.
  """
  @spec unregister_resource(String.t()) :: :ok | {:error, Error.t()}
  def unregister_resource(resource_id) do
    unregister(resource_id)
  end

  @doc """
  Gets a specific resource by ID.
  """
  @spec get_resource(String.t()) :: any() | nil
  def get_resource(resource_id) do
    case GenServer.call(__MODULE__, {:get_resource, resource_id}) do
      {:ok, resource} -> resource
      {:error, :not_found} -> nil
      _ -> nil
    end
  end

  @doc """
  Lists all registered resources.
  """
  @spec list_resources() :: list()
  def list_resources do
    case GenServer.call(__MODULE__, :list_resources) do
      {:ok, resources} -> resources
      _ -> []
    end
  end

  @doc """
  Cleans up a specific resource by ID.
  """
  @spec cleanup_resource(String.t()) :: :ok | {:error, :not_found | Error.t()}
  def cleanup_resource(resource_id) do
    GenServer.call(__MODULE__, {:cleanup_resource, resource_id})
  end

  @doc """
  Gets current resource statistics.
  """
  @spec get_resource_stats() :: {:ok, resource_stats()} | {:error, Error.t()}
  def get_resource_stats do
    GenServer.call(__MODULE__, :get_resource_stats)
  end

  @doc """
  Forces cleanup of all idle resources.
  """
  @spec cleanup_idle_resources() :: :ok | {:error, Error.t()}
  def cleanup_idle_resources do
    GenServer.call(__MODULE__, :cleanup_idle_resources)
  end

  @doc """
  Forces cleanup of all resources (emergency cleanup).
  """
  @spec force_cleanup() :: :ok | {:error, Error.t()}
  def force_cleanup do
    GenServer.call(__MODULE__, :force_cleanup)
  end

  @doc """
  Creates a resource pool for a specific resource type.

  ## Parameters

  - `pool_id` - Unique identifier for the pool
  - `type` - Resource type
  - `factory_fun` - Function to create new resources
  - `config` - Pool configuration

  ## Examples

      iex> TantivyEx.ResourceManager.create_pool("readers", :reader,
      ...>   fn -> TantivyEx.IndexReader.new(index) end,
      ...>   %{min_size: 2, max_size: 10}
      ...> )
      :ok
  """
  @spec create_pool(String.t(), resource_type(), function(), pool_config()) ::
          :ok | {:error, Error.t()}
  def create_pool(pool_id, type, factory_fun, config \\ %{}) do
    GenServer.call(__MODULE__, {:create_pool, pool_id, type, factory_fun, config})
  end

  @doc """
  Destroys a resource pool.
  """
  @spec destroy_pool(String.t()) :: :ok | {:error, Error.t()}
  def destroy_pool(pool_id) do
    GenServer.call(__MODULE__, {:destroy_pool, pool_id})
  end

  @doc """
  Checks out a resource from a pool.

  ## Parameters

  - `pool_id` - Pool identifier
  - `timeout` - Checkout timeout in milliseconds

  ## Returns

  - `{:ok, resource}` - Successfully checked out resource
  - `{:error, :timeout}` - Checkout timed out
  - `{:error, :pool_not_found}` - Pool doesn't exist

  ## Examples

      iex> {:ok, reader} = TantivyEx.ResourceManager.checkout("readers", 5000)
      iex> # Use reader
      iex> :ok = TantivyEx.ResourceManager.checkin("readers", reader)
  """
  @spec checkout(String.t(), non_neg_integer()) ::
          {:ok, any()} | {:error, :timeout | :pool_not_found | Error.t()}
  def checkout(pool_id, timeout \\ 5000) do
    GenServer.call(__MODULE__, {:checkout, pool_id, timeout})
  end

  @doc """
  Checks in a resource to a pool.
  """
  @spec checkin(String.t(), any()) :: :ok | {:error, Error.t()}
  def checkin(pool_id, resource) do
    GenServer.call(__MODULE__, {:checkin, pool_id, resource})
  end

  @doc """
  Executes a function with a pooled resource.

  The resource is automatically checked out before the function execution
  and checked back in afterward, even if an error occurs.

  ## Parameters

  - `pool_id` - Pool identifier
  - `fun` - Function to execute with the resource
  - `timeout` - Checkout timeout

  ## Examples

      iex> TantivyEx.ResourceManager.with_pooled_resource("readers", fn reader ->
      ...>   TantivyEx.Searcher.search(reader, query, 10)
      ...> end)
      {:ok, search_results}
  """
  @spec with_pooled_resource(String.t(), function(), non_neg_integer()) ::
          {:ok, any()} | {:error, Error.t()}
  def with_pooled_resource(pool_id, fun, timeout \\ 5000) when is_function(fun, 1) do
    case checkout(pool_id, timeout) do
      {:ok, resource} ->
        try do
          result = fun.(resource)
          checkin(pool_id, resource)
          {:ok, result}
        rescue
          error ->
            checkin(pool_id, resource)
            {:error, Error.wrap(error, :pooled_resource)}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Detects potential resource leaks.

  ## Returns

  Returns a list of resources that may be leaked based on usage patterns.
  """
  @spec detect_leaks() :: {:ok, [map()]} | {:error, Error.t()}
  def detect_leaks do
    GenServer.call(__MODULE__, :detect_leaks)
  end

  # GenServer implementation

  defmodule State do
    @moduledoc false

    defstruct [
      :config,
      :resources,
      :pools,
      :cleanup_timer,
      :stats,
      :leak_detector
    ]

    @type t :: %__MODULE__{
            config: map(),
            resources: map(),
            pools: map(),
            cleanup_timer: reference() | nil,
            stats: map(),
            leak_detector: map()
          }
  end

  @impl GenServer
  def init(config) do
    merged_config = Map.merge(@default_config, config)

    state = %State{
      config: merged_config,
      resources: %{},
      pools: %{},
      cleanup_timer: nil,
      stats: initialize_stats(),
      leak_detector: %{patterns: [], thresholds: %{}}
    }

    # Start cleanup timer if auto-cleanup is enabled
    timer =
      if merged_config.auto_cleanup do
        schedule_cleanup(merged_config.cleanup_interval_ms)
      else
        nil
      end

    {:ok, %{state | cleanup_timer: timer}}
  end

  @impl GenServer
  def handle_call({:configure, new_config}, _from, state) do
    merged_config = Map.merge(state.config, new_config)

    # Restart cleanup timer if interval changed
    timer =
      if merged_config.auto_cleanup and
           merged_config.cleanup_interval_ms != state.config.cleanup_interval_ms do
        if state.cleanup_timer, do: Process.cancel_timer(state.cleanup_timer)
        schedule_cleanup(merged_config.cleanup_interval_ms)
      else
        state.cleanup_timer
      end

    new_state = %{state | config: merged_config, cleanup_timer: timer}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:register, resource, type, cleanup_fun, metadata}, _from, state) do
    # Check if resource is already registered
    if Map.has_key?(state.resources, resource) do
      {:reply, {:error, :already_exists}, state}
    else
      # Check resource limits
      current_count = count_resources_by_type(state.resources, type)
      limit = get_type_limit(type, state.config)

      if current_count >= limit do
        error = %Error.SystemError{
          message: "Resource limit exceeded for type #{type}",
          resource_type: Atom.to_string(type),
          available_resources: %{current: current_count, limit: limit},
          suggestion: "Increase limit or cleanup unused resources"
        }

        {:reply, {:error, error}, state}
      else
        resource_info = %{
          resource: resource,
          type: type,
          cleanup_fun: cleanup_fun,
          created_at: DateTime.utc_now(),
          last_used: DateTime.utc_now(),
          usage_count: 0,
          pool_id: nil,
          metadata: metadata
        }

        new_resources = Map.put(state.resources, resource, resource_info)
        new_stats = update_registration_stats(state.stats, type)

        {:reply, :ok, %{state | resources: new_resources, stats: new_stats}}
      end
    end
  end

  @impl GenServer
  def handle_call({:unregister, resource}, _from, state) do
    case Map.get(state.resources, resource) do
      nil ->
        {:reply, :ok, state}

      resource_info ->
        # Perform cleanup
        try do
          resource_info.cleanup_fun.(resource)
        rescue
          error ->
            Logger.warning("Failed to cleanup resource: #{inspect(error)}")
        end

        new_resources = Map.delete(state.resources, resource)
        new_stats = update_unregistration_stats(state.stats, resource_info.type)

        {:reply, :ok, %{state | resources: new_resources, stats: new_stats}}
    end
  end

  @impl GenServer
  def handle_call({:touch, resource}, _from, state) do
    case Map.get(state.resources, resource) do
      nil ->
        {:reply, :ok, state}

      resource_info ->
        updated_info = %{
          resource_info
          | last_used: DateTime.utc_now(),
            usage_count: resource_info.usage_count + 1
        }

        new_resources = Map.put(state.resources, resource, updated_info)
        {:reply, :ok, %{state | resources: new_resources}}
    end
  end

  @impl GenServer
  def handle_call(:get_resource_stats, _from, state) do
    current_stats = calculate_current_stats(state.resources, state.pools, state.stats)
    {:reply, {:ok, current_stats}, state}
  end

  @impl GenServer
  def handle_call(:cleanup_idle_resources, _from, state) do
    {cleaned_resources, new_resources} = cleanup_idle_resources(state.resources, state.config)

    new_stats = update_cleanup_stats(state.stats, length(cleaned_resources))

    Logger.info("Cleaned up #{length(cleaned_resources)} idle resources")

    {:reply, :ok, %{state | resources: new_resources, stats: new_stats}}
  end

  @impl GenServer
  def handle_call(:force_cleanup, _from, state) do
    {cleaned_resources, new_resources} = force_cleanup_resources(state.resources)

    new_stats = update_cleanup_stats(state.stats, length(cleaned_resources))

    Logger.info("Force cleaned up #{length(cleaned_resources)} resources")

    {:reply, :ok, %{state | resources: new_resources, stats: new_stats}}
  end

  @impl GenServer
  def handle_call({:create_pool, pool_id, type, factory_fun, config}, _from, state) do
    if Map.has_key?(state.pools, pool_id) do
      error = %Error.SystemError{
        message: "Pool #{pool_id} already exists",
        suggestion: "Use a different pool ID or destroy the existing pool"
      }

      {:reply, {:error, error}, state}
    else
      pool_config = Map.merge(%{min_size: 2, max_size: 10, checkout_timeout_ms: 5000}, config)

      pool_info = %{
        type: type,
        factory_fun: factory_fun,
        config: pool_config,
        available: [],
        checked_out: %{},
        waiters: [],
        created_at: DateTime.utc_now(),
        stats: %{checkouts: 0, checkins: 0, timeouts: 0}
      }

      # Initialize pool with minimum resources
      {pool_info, _} = populate_pool(pool_info, pool_config.min_size, state.resources)

      new_pools = Map.put(state.pools, pool_id, pool_info)

      {:reply, :ok, %{state | pools: new_pools}}
    end
  end

  @impl GenServer
  def handle_call({:destroy_pool, pool_id}, _from, state) do
    case Map.get(state.pools, pool_id) do
      nil ->
        {:reply, {:error, :pool_not_found}, state}

      pool_info ->
        # Cleanup all pool resources
        cleanup_pool_resources(pool_info, state.resources)

        new_pools = Map.delete(state.pools, pool_id)
        {:reply, :ok, %{state | pools: new_pools}}
    end
  end

  @impl GenServer
  def handle_call({:checkout, pool_id, timeout}, from, state) do
    case Map.get(state.pools, pool_id) do
      nil ->
        {:reply, {:error, :pool_not_found}, state}

      pool_info ->
        case pool_info.available do
          [resource | remaining] ->
            # Resource available immediately
            new_checked_out = Map.put(pool_info.checked_out, resource, from)

            updated_pool = %{
              pool_info
              | available: remaining,
                checked_out: new_checked_out,
                stats: %{pool_info.stats | checkouts: pool_info.stats.checkouts + 1}
            }

            new_pools = Map.put(state.pools, pool_id, updated_pool)
            # Update resource usage timestamp
            updated_resources = update_resource_usage(state.resources, resource)

            {:reply, {:ok, resource}, %{state | pools: new_pools, resources: updated_resources}}

          [] ->
            # No resources available, try to create new one or queue
            if map_size(pool_info.checked_out) < pool_info.config.max_size do
              # Can create new resource
              case create_pool_resource(pool_info, state.resources) do
                {:ok, resource, updated_resources} ->
                  new_checked_out = Map.put(pool_info.checked_out, resource, from)

                  updated_pool = %{
                    pool_info
                    | checked_out: new_checked_out,
                      stats: %{pool_info.stats | checkouts: pool_info.stats.checkouts + 1}
                  }

                  new_pools = Map.put(state.pools, pool_id, updated_pool)

                  {:reply, {:ok, resource},
                   %{state | pools: new_pools, resources: updated_resources}}

                {:error, _error} ->
                  # Queue the request
                  waiter = {from, System.monotonic_time(:millisecond) + timeout}
                  updated_pool = %{pool_info | waiters: [waiter | pool_info.waiters]}
                  new_pools = Map.put(state.pools, pool_id, updated_pool)

                  {:noreply, %{state | pools: new_pools}}
              end
            else
              # Pool at max capacity, queue the request
              waiter = {from, System.monotonic_time(:millisecond) + timeout}
              updated_pool = %{pool_info | waiters: [waiter | pool_info.waiters]}
              new_pools = Map.put(state.pools, pool_id, updated_pool)

              {:noreply, %{state | pools: new_pools}}
            end
        end
    end
  end

  @impl GenServer
  def handle_call({:checkin, pool_id, resource}, _from, state) do
    case Map.get(state.pools, pool_id) do
      nil ->
        {:reply, {:error, :pool_not_found}, state}

      pool_info ->
        case Map.get(pool_info.checked_out, resource) do
          nil ->
            {:reply, {:error, :resource_not_checked_out}, state}

          _from ->
            new_checked_out = Map.delete(pool_info.checked_out, resource)

            # Check if there are waiters
            case pool_info.waiters do
              [] ->
                # No waiters, add to available pool
                updated_pool = %{
                  pool_info
                  | available: [resource | pool_info.available],
                    checked_out: new_checked_out,
                    stats: %{pool_info.stats | checkins: pool_info.stats.checkins + 1}
                }

                new_pools = Map.put(state.pools, pool_id, updated_pool)
                {:reply, :ok, %{state | pools: new_pools}}

              [{waiter_from, _deadline} | remaining_waiters] ->
                # Immediately give resource to waiter
                new_checked_out_for_waiter = Map.put(new_checked_out, resource, waiter_from)

                updated_pool = %{
                  pool_info
                  | checked_out: new_checked_out_for_waiter,
                    waiters: remaining_waiters,
                    stats: %{
                      pool_info.stats
                      | checkins: pool_info.stats.checkins + 1,
                        checkouts: pool_info.stats.checkouts + 1
                    }
                }

                new_pools = Map.put(state.pools, pool_id, updated_pool)
                GenServer.reply(waiter_from, {:ok, resource})

                {:reply, :ok, %{state | pools: new_pools}}
            end
        end
    end
  end

  @impl GenServer
  def handle_call(:detect_leaks, _from, state) do
    leaks = detect_resource_leaks(state.resources, state.config)
    {:reply, {:ok, leaks}, state}
  end

  @impl GenServer
  def handle_call({:get_resource, resource_id}, _from, state) do
    case Map.get(state.resources, resource_id) do
      nil -> {:reply, {:error, :not_found}, state}
      resource_info -> {:reply, {:ok, resource_info.resource}, state}
    end
  end

  @impl GenServer
  def handle_call(:list_resources, _from, state) do
    resources =
      state.resources
      |> Enum.map(fn {id, info} ->
        %{
          id: id,
          type: info.type,
          created_at: info.created_at,
          last_used: info.last_used,
          usage_count: info.usage_count
        }
      end)

    {:reply, {:ok, resources}, state}
  end

  @impl GenServer
  def handle_call({:cleanup_resource, resource_id}, _from, state) do
    case Map.get(state.resources, resource_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      resource_info ->
        # Cleanup the resource
        try do
          resource_info.cleanup_fun.(resource_info.resource)
          new_resources = Map.delete(state.resources, resource_id)
          new_state = %{state | resources: new_resources}
          {:reply, :ok, new_state}
        rescue
          e ->
            error = Error.wrap(e, :cleanup)
            {:reply, {:error, error}, state}
        end
    end
  end

  @impl GenServer
  def handle_info(:cleanup_resources, state) do
    # Perform scheduled cleanup
    {cleaned_count, new_resources} = cleanup_idle_resources(state.resources, state.config)

    # Process pool timeouts
    new_pools = process_pool_timeouts(state.pools)

    new_stats = update_cleanup_stats(state.stats, cleaned_count)

    if cleaned_count > 0 do
      Logger.debug("Scheduled cleanup: #{cleaned_count} resources cleaned")
    end

    # Schedule next cleanup
    timer = schedule_cleanup(state.config.cleanup_interval_ms)

    {:noreply,
     %{state | resources: new_resources, pools: new_pools, stats: new_stats, cleanup_timer: timer}}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    # Cleanup all resources
    cleanup_all_resources(state.resources)
    cleanup_all_pools(state.pools, state.resources)
    :ok
  end

  # Private helper functions

  defp initialize_stats do
    %{
      registrations: %{},
      cleanups: 0,
      pool_operations: %{checkouts: 0, checkins: 0, timeouts: 0},
      leak_detections: 0,
      total_created: 0,
      total_destroyed: 0
    }
  end

  defp schedule_cleanup(interval_ms) do
    Process.send_after(self(), :cleanup_resources, interval_ms)
  end

  defp count_resources_by_type(resources, type) do
    resources
    |> Enum.count(fn {_resource, info} -> info.type == type end)
  end

  defp get_type_limit(type, config) do
    case type do
      :writer -> config.max_writers
      :reader -> config.max_readers
      :index -> config.max_indexes
      :query -> config.max_cached_queries
      :native -> config.max_native_objects
      # Default limit
      _ -> 1000
    end
  end

  defp update_registration_stats(stats, type) do
    new_registrations = Map.update(stats.registrations, type, 1, &(&1 + 1))
    %{stats | registrations: new_registrations, total_created: stats.total_created + 1}
  end

  defp update_unregistration_stats(stats, type) do
    new_registrations = Map.update(stats.registrations, type, 0, &max(&1 - 1, 0))
    %{stats | registrations: new_registrations, total_destroyed: stats.total_destroyed + 1}
  end

  defp update_cleanup_stats(stats, cleaned_count) do
    %{stats | cleanups: stats.cleanups + cleaned_count}
  end

  defp cleanup_idle_resources(resources, config) do
    idle_threshold = DateTime.add(DateTime.utc_now(), -config.idle_timeout_ms, :millisecond)

    {idle_resources, active_resources} =
      Enum.split_with(resources, fn {_resource, info} ->
        DateTime.compare(info.last_used, idle_threshold) == :lt
      end)

    # Cleanup idle resources
    Enum.each(idle_resources, fn {resource, info} ->
      try do
        info.cleanup_fun.(resource)
      rescue
        error ->
          Logger.warning("Failed to cleanup idle resource: #{inspect(error)}")
      end
    end)

    {idle_resources, Map.new(active_resources)}
  end

  defp force_cleanup_resources(resources) do
    # Cleanup all non-pooled resources
    {non_pooled, pooled} =
      Enum.split_with(resources, fn {_resource, info} ->
        is_nil(info.pool_id)
      end)

    Enum.each(non_pooled, fn {resource, info} ->
      try do
        info.cleanup_fun.(resource)
      rescue
        error ->
          Logger.warning("Failed to force cleanup resource: #{inspect(error)}")
      end
    end)

    {non_pooled, Map.new(pooled)}
  end

  defp cleanup_all_resources(resources) do
    Enum.each(resources, fn {resource, info} ->
      try do
        info.cleanup_fun.(resource)
      rescue
        error ->
          Logger.warning("Failed to cleanup resource during shutdown: #{inspect(error)}")
      end
    end)
  end

  defp cleanup_all_pools(pools, resources) do
    Enum.each(pools, fn {_pool_id, pool_info} ->
      cleanup_pool_resources(pool_info, resources)
    end)
  end

  defp cleanup_pool_resources(pool_info, resources) do
    all_pool_resources = pool_info.available ++ Map.keys(pool_info.checked_out)

    Enum.each(all_pool_resources, fn resource ->
      case Map.get(resources, resource) do
        nil ->
          :ok

        resource_info ->
          try do
            resource_info.cleanup_fun.(resource)
          rescue
            error ->
              Logger.warning("Failed to cleanup pool resource: #{inspect(error)}")
          end
      end
    end)
  end

  defp populate_pool(pool_info, count, resources) do
    Enum.reduce(0..(count - 1), {pool_info, resources}, fn _i, {pool_acc, resources_acc} ->
      case create_pool_resource(pool_acc, resources_acc) do
        {:ok, resource, new_resources} ->
          updated_pool = %{pool_acc | available: [resource | pool_acc.available]}
          {updated_pool, new_resources}

        {:error, _error} ->
          {pool_acc, resources_acc}
      end
    end)
  end

  defp create_pool_resource(pool_info, resources) do
    try do
      case pool_info.factory_fun.() do
        {:ok, resource} ->
          # Register the resource
          resource_info = %{
            resource: resource,
            type: pool_info.type,
            # Pool handles cleanup
            cleanup_fun: fn _ -> :ok end,
            created_at: DateTime.utc_now(),
            last_used: DateTime.utc_now(),
            usage_count: 0,
            # Will be set when registered with pool
            pool_id: nil,
            metadata: %{}
          }

          new_resources = Map.put(resources, resource, resource_info)
          {:ok, resource, new_resources}

        resource when not is_tuple(resource) ->
          # Assume successful creation if not tuple
          resource_info = %{
            resource: resource,
            type: pool_info.type,
            cleanup_fun: fn _ -> :ok end,
            created_at: DateTime.utc_now(),
            last_used: DateTime.utc_now(),
            usage_count: 0,
            pool_id: nil,
            metadata: %{}
          }

          new_resources = Map.put(resources, resource, resource_info)
          {:ok, resource, new_resources}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        {:error, error}
    end
  end

  defp process_pool_timeouts(pools) do
    current_time = System.monotonic_time(:millisecond)

    Enum.reduce(pools, %{}, fn {pool_id, pool_info}, acc ->
      {timed_out_waiters, active_waiters} =
        Enum.split_with(pool_info.waiters, fn {_from, deadline} ->
          current_time >= deadline
        end)

      # Reply to timed out waiters
      Enum.each(timed_out_waiters, fn {from, _deadline} ->
        GenServer.reply(from, {:error, :timeout})
      end)

      updated_pool = %{
        pool_info
        | waiters: active_waiters,
          stats: %{
            pool_info.stats
            | timeouts: pool_info.stats.timeouts + length(timed_out_waiters)
          }
      }

      Map.put(acc, pool_id, updated_pool)
    end)
  end

  defp calculate_current_stats(resources, pools, stats) do
    by_type =
      Enum.reduce(resources, %{}, fn {_resource, info}, acc ->
        Map.update(acc, info.type, 1, &(&1 + 1))
      end)

    pool_stats =
      Enum.reduce(pools, %{}, fn {pool_id, pool_info}, acc ->
        pool_stat = %{
          available: length(pool_info.available),
          checked_out: map_size(pool_info.checked_out),
          waiters: length(pool_info.waiters),
          stats: pool_info.stats
        }

        Map.put(acc, pool_id, pool_stat)
      end)

    memory_usage =
      case TantivyEx.Memory.get_stats() do
        {:ok, memory_stats} -> memory_stats
        {:error, _} -> %{}
      end

    %{
      total_resources: map_size(resources),
      by_type: by_type,
      pool_stats: pool_stats,
      cleanup_stats: %{
        cleanups: stats.cleanups,
        total_created: stats.total_created,
        total_destroyed: stats.total_destroyed
      },
      memory_usage: memory_usage
    }
  end

  defp detect_resource_leaks(resources, config) do
    if config.leak_detection do
      current_time = DateTime.utc_now()
      old_threshold = DateTime.add(current_time, -config.idle_timeout_ms * 3, :millisecond)

      resources
      |> Enum.filter(fn {_resource, info} ->
        DateTime.compare(info.last_used, old_threshold) == :lt and info.usage_count == 0
      end)
      |> Enum.map(fn {resource, info} ->
        %{
          resource: resource,
          type: info.type,
          created_at: info.created_at,
          last_used: info.last_used,
          usage_count: info.usage_count,
          age_ms: DateTime.diff(current_time, info.created_at, :millisecond),
          idle_ms: DateTime.diff(current_time, info.last_used, :millisecond)
        }
      end)
    else
      []
    end
  end

  defp update_resource_usage(resources, resource) do
    case Map.get(resources, resource) do
      nil ->
        resources

      resource_info ->
        updated_info = %{
          resource_info
          | last_used: DateTime.utc_now(),
            usage_count: resource_info.usage_count + 1
        }

        Map.put(resources, resource, updated_info)
    end
  end
end
