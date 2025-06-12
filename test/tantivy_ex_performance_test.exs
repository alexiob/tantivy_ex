defmodule TantivyEx.PerformanceTest do
  use ExUnit.Case, async: false
  alias TantivyEx.Performance
  alias TantivyEx.{Index, Schema}

  setup do
    # Ensure the Performance GenServer is running and healthy
    case Process.whereis(TantivyEx.Performance) do
      nil ->
        # GenServer is not running, start it
        {:ok, _pid} = Performance.start_link([])
        :ok

      pid when is_pid(pid) ->
        # GenServer exists, check if it's alive
        if Process.alive?(pid) do
          :ok
        else
          # Process is dead, start a new one
          {:ok, _pid} = Performance.start_link([])
          :ok
        end
    end
  end

  describe "merge policy configuration" do
    test "configures no merge policy" do
      assert :ok = Performance.set_merge_policy(:no_merge)
      assert Performance.get_merge_policy() == :no_merge
    end

    test "configures log merge policy with default settings" do
      assert :ok = Performance.set_merge_policy(:log_merge)
      assert Performance.get_merge_policy() == :log_merge
    end

    test "configures log merge policy with custom settings" do
      options = [
        min_merge_size: 8,
        min_layer_size: 10_000,
        level_log_size: 0.75
      ]

      assert :ok = Performance.set_merge_policy(:log_merge, options)
      policy = Performance.get_merge_policy()
      assert policy.type == :log_merge
      assert policy.options[:min_merge_size] == 8
    end

    test "configures temporal merge policy" do
      options = [max_docs_before_merge: 100_000]
      assert :ok = Performance.set_merge_policy(:temporal_merge, options)

      policy = Performance.get_merge_policy()
      assert policy.type == :temporal_merge
      assert policy.options[:max_docs_before_merge] == 100_000
    end

    test "rejects invalid merge policy" do
      assert {:error, _} = Performance.set_merge_policy(:invalid_policy)
    end
  end

  describe "thread pool management" do
    test "configures search thread pool" do
      assert :ok = Performance.configure_thread_pool(:search, 4)
      config = Performance.get_thread_pool_config(:search)
      assert config.size == 4
    end

    test "configures indexing thread pool" do
      assert :ok = Performance.configure_thread_pool(:indexing, 2)
      config = Performance.get_thread_pool_config(:indexing)
      assert config.size == 2
    end

    test "configures merge thread pool" do
      assert :ok = Performance.configure_thread_pool(:merge, 1)
      config = Performance.get_thread_pool_config(:merge)
      assert config.size == 1
    end

    test "rejects invalid thread pool type" do
      assert {:error, _} = Performance.configure_thread_pool(:invalid, 4)
    end

    test "rejects invalid thread count" do
      assert {:error, _} = Performance.configure_thread_pool(:search, 0)
      assert {:error, _} = Performance.configure_thread_pool(:search, -1)
    end
  end

  describe "index optimization" do
    test "optimizes index successfully" do
      # Create a temporary index for testing
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)
        |> Schema.add_text_field("body", stored: true)

      {:ok, index} = Index.create_in_ram(schema)

      assert {:ok, _stats} = Performance.optimize_index(index)
    end

    test "compacts index successfully" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)

      {:ok, index} = Index.create_in_ram(schema)

      assert {:ok, _stats} = Performance.compact_index(index)
    end

    test "force merges index segments" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)

      {:ok, index} = Index.create_in_ram(schema)

      assert {:ok, _stats} = Performance.force_merge(index, max_segments: 1)
    end
  end

  describe "background operations" do
    test "starts background merging" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)

      {:ok, index} = Index.create_in_ram(schema)

      assert :ok = Performance.start_background_merge(index)
      assert Performance.is_background_merge_active?(index)
    end

    test "stops background merging" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)

      {:ok, index} = Index.create_in_ram(schema)

      :ok = Performance.start_background_merge(index)
      assert :ok = Performance.stop_background_merge(index)
      refute Performance.is_background_merge_active?(index)
    end

    test "schedules index optimization" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)

      {:ok, index} = Index.create_in_ram(schema)

      # Schedule optimization every 5 minutes
      assert :ok = Performance.schedule_optimization(index, interval: 300_000)

      scheduled = Performance.get_scheduled_operations(index)
      assert Enum.any?(scheduled, &(&1.type == :optimization))
    end
  end

  describe "performance monitoring" do
    test "gets performance statistics" do
      stats = Performance.get_statistics()

      assert is_map(stats)
      assert Map.has_key?(stats, :merge_operations)
      assert Map.has_key?(stats, :optimization_operations)
      assert Map.has_key?(stats, :thread_pool_usage)
      assert Map.has_key?(stats, :background_operations)
    end

    test "profiles operation performance" do
      operation = fn ->
        :timer.sleep(10)
        {:ok, "result"}
      end

      {:ok, result, profile} = Performance.profile_operation(operation, "test_operation")

      assert result == "result"
      assert is_map(profile)
      assert Map.has_key?(profile, :duration_ms)
      assert Map.has_key?(profile, :memory_usage)
      assert profile.operation_name == "test_operation"
    end

    test "monitors operation with timeout" do
      quick_operation = fn -> {:ok, "quick"} end

      slow_operation = fn ->
        :timer.sleep(200)
        {:ok, "slow"}
      end

      # Quick operation should succeed
      assert {:ok, "quick", _} = Performance.monitor_operation(quick_operation, timeout: 100)

      # Slow operation should timeout
      assert {:error, :timeout} = Performance.monitor_operation(slow_operation, timeout: 100)
    end
  end

  describe "optimization recommendations" do
    test "gets optimization recommendations" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)

      {:ok, index} = Index.create_in_ram(schema)

      recommendations = Performance.get_optimization_recommendations(index)

      assert is_list(recommendations)
      # New index should have minimal recommendations
      assert Enum.all?(
               recommendations,
               &(Map.has_key?(&1, :type) and Map.has_key?(&1, :priority))
             )
    end

    test "applies optimization recommendations" do
      # Ensure Performance GenServer is running
      case Performance.start_link([]) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
      end

      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)

      {:ok, index} = Index.create_in_ram(schema)

      recommendations = [
        %{type: :merge_policy, priority: :medium, action: :set_log_merge},
        %{type: :thread_pool, priority: :low, action: :increase_search_threads}
      ]

      results = Performance.apply_recommendations(index, recommendations)

      assert is_list(results)
      assert length(results) == length(recommendations)
    end
  end

  describe "auto optimization" do
    test "enables auto optimization" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)

      {:ok, index} = Index.create_in_ram(schema)

      options = [
        trigger_threshold: 0.8,
        check_interval: 60_000,
        max_optimizations_per_hour: 2
      ]

      assert :ok = Performance.enable_auto_optimization(index, options)
      assert Performance.is_auto_optimization_enabled?(index)
    end

    test "disables auto optimization" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", stored: true)

      {:ok, index} = Index.create_in_ram(schema)

      :ok = Performance.enable_auto_optimization(index, [])
      assert :ok = Performance.disable_auto_optimization(index)
      refute Performance.is_auto_optimization_enabled?(index)
    end
  end

  describe "concurrency controls" do
    test "sets concurrency limits" do
      limits = %{
        max_concurrent_searches: 10,
        max_concurrent_writes: 2,
        max_concurrent_merges: 1
      }

      assert :ok = Performance.set_concurrency_limits(limits)
      current_limits = Performance.get_concurrency_limits()

      assert current_limits.max_concurrent_searches == 10
      assert current_limits.max_concurrent_writes == 2
      assert current_limits.max_concurrent_merges == 1
    end

    test "acquires and releases operation permits" do
      Performance.set_concurrency_limits(%{max_concurrent_searches: 2})

      assert {:ok, permit1} = Performance.acquire_permit(:search)
      assert {:ok, _permit2} = Performance.acquire_permit(:search)

      # Third permit should be denied
      assert {:error, :no_permits_available} = Performance.acquire_permit(:search)

      # Release one permit
      assert :ok = Performance.release_permit(permit1)

      # Now we should be able to acquire again
      assert {:ok, _permit3} = Performance.acquire_permit(:search)
    end
  end

  describe "error handling" do
    test "handles optimization errors gracefully" do
      # Try to optimize an invalid reference
      assert {:error, _reason} = Performance.optimize_index("invalid_index")
    end

    test "handles merge policy configuration errors" do
      invalid_options = [invalid_option: "bad_value"]
      assert {:error, _reason} = Performance.set_merge_policy(:log_merge, invalid_options)
    end

    test "handles thread pool configuration errors" do
      assert {:error, _reason} = Performance.configure_thread_pool(:search, "invalid_size")
    end
  end
end
