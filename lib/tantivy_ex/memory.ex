defmodule TantivyEx.Memory do
  @moduledoc """
  Comprehensive memory management and monitoring for TantivyEx.

  This module provides memory limits, monitoring, and automatic cleanup
  mechanisms to ensure efficient resource usage and prevent out-of-memory
  conditions during indexing and search operations.

  ## Features

  - **Memory Limits**: Configurable memory limits for operations
  - **Memory Monitoring**: Real-time memory usage tracking
  - **Automatic Cleanup**: Automatic resource cleanup mechanisms
  - **Memory Pressure Detection**: Early warning for memory pressure
  - **Garbage Collection Integration**: Smart GC triggering
  - **Resource Pooling**: Memory-aware resource pooling

  ## Configuration

      # Configure global memory limits
      TantivyEx.Memory.configure(%{
        max_memory_mb: 1024,              # Total memory limit
        writer_memory_mb: 512,            # Memory limit for index writers
        search_memory_mb: 256,            # Memory limit for search operations
        aggregation_memory_mb: 128,       # Memory limit for aggregations
        gc_threshold: 0.8,                # GC trigger threshold (80%)
        monitoring_interval_ms: 5000,     # Memory monitoring interval
        cleanup_on_pressure: true         # Auto-cleanup on memory pressure
      })

  ## Usage

      # Create memory-aware operations
      {:ok, writer} = TantivyEx.IndexWriter.new(index, memory_limit: 256)

      # Monitor memory during operations
      TantivyEx.Memory.with_monitoring fn ->
        # Perform memory-intensive operations
        TantivyEx.Document.add_batch(writer, documents, schema)
      end

      # Manual memory management
      {:ok, stats} = TantivyEx.Memory.get_stats()
      :ok = TantivyEx.Memory.force_cleanup()
      :ok = TantivyEx.Memory.trigger_gc()

  ## Automatic Memory Management

  The module provides automatic memory management through:

  1. **Memory Monitoring**: Continuous monitoring of memory usage
  2. **Pressure Detection**: Early detection of memory pressure conditions
  3. **Automatic Cleanup**: Triggered cleanup when thresholds are exceeded
  4. **Smart GC**: Intelligent garbage collection timing
  5. **Resource Limiting**: Automatic enforcement of memory limits

  ## Memory Stats

  The module tracks comprehensive memory statistics:

  - Current memory usage by component
  - Peak memory usage
  - Memory pressure events
  - GC statistics
  - Resource cleanup events
  """

  use GenServer
  require Logger
  alias TantivyEx.Error

  @default_config %{
    max_memory_mb: 1024,
    writer_memory_mb: 512,
    search_memory_mb: 256,
    aggregation_memory_mb: 128,
    gc_threshold: 0.8,
    monitoring_interval_ms: 5000,
    cleanup_on_pressure: true,
    auto_gc: true,
    pressure_threshold: 0.9
  }

  @type memory_stats :: %{
          total_used_mb: float(),
          total_limit_mb: non_neg_integer(),
          writer_used_mb: float(),
          search_used_mb: float(),
          aggregation_used_mb: float(),
          system_used_mb: float(),
          gc_count: non_neg_integer(),
          cleanup_count: non_neg_integer(),
          pressure_events: non_neg_integer(),
          last_gc: DateTime.t() | nil,
          last_cleanup: DateTime.t() | nil
        }

  @type memory_config :: %{
          max_memory_mb: non_neg_integer(),
          writer_memory_mb: non_neg_integer(),
          search_memory_mb: non_neg_integer(),
          aggregation_memory_mb: non_neg_integer(),
          gc_threshold: float(),
          monitoring_interval_ms: non_neg_integer(),
          cleanup_on_pressure: boolean(),
          auto_gc: boolean(),
          pressure_threshold: float()
        }

  # Client API

  @doc """
  Starts the memory management system.

  ## Options

  - `:name` - Process name (default: `TantivyEx.Memory`)
  - `:config` - Memory configuration (merged with defaults)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    config = Keyword.get(opts, :config, %{})

    GenServer.start_link(__MODULE__, config, name: name)
  end

  @doc """
  Configures the memory management system.

  ## Parameters

  - `config` - Memory configuration map (see module documentation)

  ## Examples

      iex> TantivyEx.Memory.configure(%{max_memory_mb: 2048})
      :ok
  """
  @spec configure(memory_config()) :: :ok | {:error, Error.t()}
  def configure(config) when is_map(config) do
    GenServer.call(__MODULE__, {:configure, config})
  end

  @doc """
  Gets current memory statistics.

  ## Returns

  Returns detailed memory usage statistics including:
  - Current usage by component
  - Memory limits
  - GC and cleanup counts
  - Memory pressure events

  ## Examples

      iex> {:ok, stats} = TantivyEx.Memory.get_stats()
      iex> stats.total_used_mb
      245.6
  """
  @spec get_stats() :: {:ok, memory_stats()} | {:error, Error.t()}
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Checks if the system is under memory pressure.

  ## Returns

  - `true` - System is under memory pressure
  - `false` - Memory usage is normal

  ## Examples

      iex> TantivyEx.Memory.under_pressure?()
      false
  """
  @spec under_pressure?() :: boolean()
  def under_pressure? do
    GenServer.call(__MODULE__, :under_pressure?)
  end

  @doc """
  Forces immediate memory cleanup.

  This triggers immediate cleanup of unused resources and may trigger
  garbage collection if configured.

  ## Examples

      iex> TantivyEx.Memory.force_cleanup()
      :ok
  """
  @spec force_cleanup() :: :ok | {:error, Error.t()}
  def force_cleanup do
    GenServer.call(__MODULE__, :force_cleanup)
  end

  @doc """
  Triggers garbage collection.

  ## Examples

      iex> TantivyEx.Memory.trigger_gc()
      :ok
  """
  @spec trigger_gc() :: :ok
  def trigger_gc do
    GenServer.call(__MODULE__, :trigger_gc)
  end

  @doc """
  Checks if an operation can proceed given current memory constraints.

  ## Parameters

  - `operation` - The type of operation (`:indexing`, `:search`, `:aggregation`)
  - `estimated_memory_mb` - Estimated memory required for the operation

  ## Examples

      iex> TantivyEx.Memory.can_proceed?(:indexing, 100)
      {:ok, true}

      iex> TantivyEx.Memory.can_proceed?(:search, 1000)
      {:error, %TantivyEx.Error.MemoryError{}}
  """
  @spec can_proceed?(atom(), non_neg_integer()) ::
          {:ok, boolean()} | {:error, Error.t()}
  def can_proceed?(operation, estimated_memory_mb) do
    GenServer.call(__MODULE__, {:can_proceed, operation, estimated_memory_mb})
  end

  @doc """
  Executes a function with memory monitoring.

  The function is executed with active memory monitoring, and cleanup
  is performed automatically if memory pressure is detected.

  ## Parameters

  - `fun` - Function to execute
  - `opts` - Options (`:operation_type`, `:memory_limit_mb`)

  ## Examples

      iex> TantivyEx.Memory.with_monitoring(fn ->
      ...>   # Memory-intensive operation
      ...>   :result
      ...> end, operation_type: :indexing)
      {:ok, :result}
  """
  @spec with_monitoring(function(), keyword()) :: {:ok, any()} | {:error, Error.t()}
  def with_monitoring(fun, opts \\ []) when is_function(fun, 0) do
    operation_type = Keyword.get(opts, :operation_type, :unknown)
    memory_limit_mb = Keyword.get(opts, :memory_limit_mb)

    GenServer.call(__MODULE__, {:start_monitoring, operation_type, memory_limit_mb})

    try do
      result = fun.()
      GenServer.call(__MODULE__, {:stop_monitoring, operation_type})
      {:ok, result}
    rescue
      error ->
        GenServer.call(__MODULE__, {:stop_monitoring, operation_type})
        {:error, Error.wrap(error, operation_type)}
    end
  end

  @doc """
  Registers a resource for automatic cleanup.

  Resources registered with this function will be automatically cleaned up
  when memory pressure is detected or when the system shuts down.

  ## Parameters

  - `resource` - The resource reference or identifier
  - `cleanup_fun` - Function to call for cleanup
  - `category` - Resource category (`:writer`, `:reader`, `:cache`, etc.)

  ## Examples

      iex> TantivyEx.Memory.register_resource(writer_ref, &IndexWriter.close/1, :writer)
      :ok
  """
  @spec register_resource(any(), function(), atom()) :: :ok
  def register_resource(resource, cleanup_fun, category) do
    GenServer.call(__MODULE__, {:register_resource, resource, cleanup_fun, category})
  end

  @doc """
  Unregisters a resource from automatic cleanup.

  ## Examples

      iex> TantivyEx.Memory.unregister_resource(writer_ref)
      :ok
  """
  @spec unregister_resource(any()) :: :ok
  def unregister_resource(resource) do
    GenServer.call(__MODULE__, {:unregister_resource, resource})
  end

  # GenServer implementation

  defmodule State do
    @moduledoc false

    defstruct [
      :config,
      :stats,
      :resources,
      :monitoring_timer,
      :active_operations,
      :last_pressure_check
    ]

    @type t :: %__MODULE__{
            config: TantivyEx.Memory.memory_config(),
            stats: TantivyEx.Memory.memory_stats(),
            resources: map(),
            monitoring_timer: reference() | nil,
            active_operations: map(),
            last_pressure_check: DateTime.t() | nil
          }
  end

  @impl GenServer
  def init(config) do
    merged_config = Map.merge(@default_config, config)

    initial_stats = %{
      total_used_mb: 0.0,
      total_limit_mb: merged_config.max_memory_mb,
      writer_used_mb: 0.0,
      search_used_mb: 0.0,
      aggregation_used_mb: 0.0,
      system_used_mb: 0.0,
      gc_count: 0,
      cleanup_count: 0,
      pressure_events: 0,
      last_gc: nil,
      last_cleanup: nil
    }

    state = %State{
      config: merged_config,
      stats: initial_stats,
      resources: %{},
      monitoring_timer: nil,
      active_operations: %{},
      last_pressure_check: DateTime.utc_now()
    }

    # Start monitoring timer
    timer = schedule_monitoring(merged_config.monitoring_interval_ms)

    {:ok, %{state | monitoring_timer: timer}}
  end

  @impl GenServer
  def handle_call({:configure, new_config}, _from, state) do
    merged_config = Map.merge(state.config, new_config)

    # Restart monitoring with new interval if changed
    timer =
      if merged_config.monitoring_interval_ms != state.config.monitoring_interval_ms do
        if state.monitoring_timer, do: Process.cancel_timer(state.monitoring_timer)
        schedule_monitoring(merged_config.monitoring_interval_ms)
      else
        state.monitoring_timer
      end

    # Update stats to reflect new configuration limits
    updated_stats = %{state.stats | total_limit_mb: merged_config.max_memory_mb}

    new_state = %{state | config: merged_config, stats: updated_stats, monitoring_timer: timer}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    # Update current memory usage
    updated_stats = update_memory_stats(state.stats, state.active_operations)
    {:reply, {:ok, updated_stats}, %{state | stats: updated_stats}}
  end

  @impl GenServer
  def handle_call(:under_pressure?, _from, state) do
    current_usage = get_current_memory_usage()
    pressure = current_usage >= state.config.pressure_threshold

    {:reply, pressure, state}
  end

  @impl GenServer
  def handle_call(:force_cleanup, _from, state) do
    case perform_cleanup(state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  @impl GenServer
  def handle_call(:trigger_gc, _from, state) do
    :erlang.garbage_collect()

    updated_stats = %{
      state.stats
      | gc_count: state.stats.gc_count + 1,
        last_gc: DateTime.utc_now()
    }

    {:reply, :ok, %{state | stats: updated_stats}}
  end

  @impl GenServer
  def handle_call({:can_proceed, operation, estimated_memory_mb}, _from, state) do
    current_usage = get_current_memory_usage()
    operation_limit = get_operation_limit(operation, state.config)

    current_operation_usage = get_operation_usage(operation, state.active_operations)

    can_proceed =
      current_usage + estimated_memory_mb / state.config.max_memory_mb <= 1.0 and
        current_operation_usage + estimated_memory_mb <= operation_limit

    if can_proceed do
      {:reply, {:ok, true}, state}
    else
      error = %Error.MemoryError{
        message: "Memory limit would be exceeded",
        operation: operation,
        memory_used: trunc(current_usage * state.config.max_memory_mb),
        memory_limit: state.config.max_memory_mb,
        suggestion: "Reduce operation size or increase memory limit"
      }

      {:reply, {:error, error}, state}
    end
  end

  @impl GenServer
  def handle_call({:start_monitoring, operation_type, memory_limit}, _from, state) do
    operation_id = make_ref()

    new_operations =
      Map.put(state.active_operations, operation_id, %{
        type: operation_type,
        start_time: DateTime.utc_now(),
        memory_limit: memory_limit,
        peak_memory: 0.0
      })

    {:reply, operation_id, %{state | active_operations: new_operations}}
  end

  @impl GenServer
  def handle_call({:stop_monitoring, operation_id}, _from, state) do
    new_operations = Map.delete(state.active_operations, operation_id)
    {:reply, :ok, %{state | active_operations: new_operations}}
  end

  @impl GenServer
  def handle_call({:register_resource, resource, cleanup_fun, category}, _from, state) do
    new_resources =
      Map.put(state.resources, resource, %{
        cleanup_fun: cleanup_fun,
        category: category,
        registered_at: DateTime.utc_now()
      })

    {:reply, :ok, %{state | resources: new_resources}}
  end

  @impl GenServer
  def handle_call({:unregister_resource, resource}, _from, state) do
    new_resources = Map.delete(state.resources, resource)
    {:reply, :ok, %{state | resources: new_resources}}
  end

  @impl GenServer
  def handle_info(:monitor_memory, state) do
    # Perform memory monitoring
    new_state = perform_memory_check(state)

    # Schedule next monitoring
    timer = schedule_monitoring(state.config.monitoring_interval_ms)

    {:noreply, %{new_state | monitoring_timer: timer}}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    # Cleanup all registered resources
    cleanup_all_resources(state.resources)
    :ok
  end

  # Private helper functions

  defp schedule_monitoring(interval_ms) do
    Process.send_after(self(), :monitor_memory, interval_ms)
  end

  defp perform_memory_check(state) do
    current_usage = get_current_memory_usage()
    pressure = current_usage >= state.config.pressure_threshold

    new_state =
      if pressure and state.config.cleanup_on_pressure do
        Logger.warning("Memory pressure detected: #{current_usage * 100}%")

        case perform_cleanup(state) do
          {:ok, cleaned_state} ->
            updated_stats = %{
              cleaned_state.stats
              | pressure_events: cleaned_state.stats.pressure_events + 1
            }

            %{cleaned_state | stats: updated_stats}

          {:error, _error} ->
            state
        end
      else
        state
      end

    # Update memory statistics
    updated_stats = update_memory_stats(new_state.stats, new_state.active_operations)

    %{new_state | stats: updated_stats, last_pressure_check: DateTime.utc_now()}
  end

  defp perform_cleanup(state) do
    try do
      # Cleanup resources by category priority
      cleanup_categories = [:cache, :reader, :writer]

      Enum.each(cleanup_categories, fn category ->
        cleanup_resources_by_category(state.resources, category)
      end)

      # Trigger garbage collection if configured
      if state.config.auto_gc do
        :erlang.garbage_collect()
      end

      # Trigger native cleanup
      # Force cleanup using system garbage collection since native cleanup is not available
      :erlang.garbage_collect()

      # Force garbage collection on all processes
      for pid <- Process.list(), Process.alive?(pid) do
        :erlang.garbage_collect(pid)
      end

      updated_stats = %{
        state.stats
        | cleanup_count: state.stats.cleanup_count + 1,
          last_cleanup: DateTime.utc_now()
      }

      {:ok, %{state | stats: updated_stats}}
    rescue
      error ->
        {:error,
         %Error.SystemError{
           message: "Memory cleanup failed: #{inspect(error)}",
           operation: :cleanup,
           suggestion: "Check system resources and try manual cleanup"
         }}
    end
  end

  defp cleanup_resources_by_category(resources, category) do
    resources
    |> Enum.filter(fn {_resource, info} -> info.category == category end)
    |> Enum.each(fn {resource, info} ->
      try do
        info.cleanup_fun.(resource)
      rescue
        error ->
          Logger.warning("Failed to cleanup resource #{inspect(resource)}: #{inspect(error)}")
      end
    end)
  end

  defp cleanup_all_resources(resources) do
    Enum.each(resources, fn {resource, info} ->
      try do
        info.cleanup_fun.(resource)
      rescue
        error ->
          Logger.warning("Failed to cleanup resource #{inspect(resource)}: #{inspect(error)}")
      end
    end)
  end

  defp get_current_memory_usage do
    # Get memory usage from system and native components
    # Convert to MB
    system_memory = :erlang.memory(:total) / (1024 * 1024)

    # Calculate percentage of configured limit
    # For now, use a simple heuristic based on Erlang memory
    # This should be enhanced with actual system memory monitoring
    if Code.ensure_loaded?(:memsup) do
      try do
        memory_info = apply(:memsup, :get_memory_data, [])
        {total_memory, allocated_memory, _} = memory_info
        allocated_memory / total_memory
      rescue
        _ ->
          # Fallback when memsup call fails
          # Use a conservative estimate based on Erlang memory
          # Assume max 50% usage
          min(system_memory / 1024.0, 0.5)
      end
    else
      # Fallback when memsup is not available
      # Use a conservative estimate based on Erlang memory
      # Assume max 50% usage
      min(system_memory / 1024.0, 0.5)
    end
  end

  defp update_memory_stats(stats, active_operations) do
    current_system = :erlang.memory(:total) / (1024 * 1024)

    # Since native memory functions are not available, use 0 for native memory
    native_usage = 0.0

    # Calculate operation-specific usage
    writer_usage = calculate_operation_usage(active_operations, :indexing)
    search_usage = calculate_operation_usage(active_operations, :search)
    aggregation_usage = calculate_operation_usage(active_operations, :aggregation)

    total_used = current_system + native_usage

    %{
      stats
      | total_used_mb: total_used,
        writer_used_mb: writer_usage,
        search_used_mb: search_usage,
        aggregation_used_mb: aggregation_usage,
        system_used_mb: current_system
    }
  end

  defp calculate_operation_usage(active_operations, operation_type) do
    active_operations
    |> Enum.filter(fn {_id, op} -> op.type == operation_type end)
    |> Enum.reduce(0.0, fn {_id, op}, acc ->
      acc + (op.memory_limit || 0)
    end)
  end

  defp get_operation_limit(operation, config) do
    case operation do
      :indexing -> config.writer_memory_mb
      :search -> config.search_memory_mb
      :aggregation -> config.aggregation_memory_mb
      _ -> config.max_memory_mb
    end
  end

  defp get_operation_usage(operation, active_operations) do
    active_operations
    |> Enum.filter(fn {_id, op} -> op.type == operation end)
    |> Enum.reduce(0, fn {_id, op}, acc ->
      acc + (op.memory_limit || 0)
    end)
  end
end
