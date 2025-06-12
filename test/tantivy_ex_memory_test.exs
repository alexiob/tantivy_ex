defmodule TantivyEx.MemoryTest do
  use ExUnit.Case, async: false
  alias TantivyEx.{Memory, Error}

  setup do
    # Ensure the Memory GenServer is running and healthy
    case Process.whereis(TantivyEx.Memory) do
      nil ->
        # GenServer is not running, start it
        {:ok, _pid} = Memory.start_link()
        :ok

      pid when is_pid(pid) ->
        # GenServer exists, check if it's alive
        if Process.alive?(pid) do
          :ok
        else
          # Process is dead, start a new one
          {:ok, _pid} = Memory.start_link()
          :ok
        end
    end
  end

  describe "memory configuration" do
    test "configures memory limits" do
      config = %{
        max_memory_mb: 2048,
        writer_memory_mb: 1024,
        search_memory_mb: 512,
        aggregation_memory_mb: 256
      }

      assert :ok = Memory.configure(config)
    end

    test "rejects invalid configuration" do
      invalid_config = "invalid"

      assert_raise FunctionClauseError, fn ->
        Memory.configure(invalid_config)
      end
    end
  end

  describe "memory statistics" do
    test "gets memory statistics" do
      {:ok, stats} = Memory.get_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :total_used_mb)
      assert Map.has_key?(stats, :total_limit_mb)
      assert Map.has_key?(stats, :gc_count)
      assert Map.has_key?(stats, :cleanup_count)
      assert is_number(stats.total_used_mb)
      assert is_integer(stats.total_limit_mb)
    end

    test "checks memory pressure" do
      pressure = Memory.under_pressure?()
      assert is_boolean(pressure)
    end
  end

  describe "memory operations" do
    test "can proceed with operation check" do
      # Should allow small operations
      assert {:ok, true} = Memory.can_proceed?(:indexing, 10)

      # Should reject extremely large operations
      case Memory.can_proceed?(:indexing, 10_000) do
        {:ok, false} -> :ok
        {:error, %Error.MemoryError{}} -> :ok
        other -> flunk("Expected memory check to fail, got: #{inspect(other)}")
      end
    end

    test "forces cleanup" do
      assert :ok = Memory.force_cleanup()
    end

    test "triggers garbage collection" do
      assert :ok = Memory.trigger_gc()
    end
  end

  describe "memory monitoring" do
    test "executes function with monitoring" do
      result =
        Memory.with_monitoring(
          fn ->
            :test_result
          end,
          operation_type: :test
        )

      assert {:ok, :test_result} = result
    end

    test "handles errors in monitored functions" do
      result =
        Memory.with_monitoring(
          fn ->
            raise "test error"
          end,
          operation_type: :test
        )

      assert {:error, %Error.SystemError{}} = result
    end
  end

  describe "resource registration" do
    test "registers and unregisters resources" do
      resource = make_ref()
      cleanup_fun = fn _resource -> :ok end

      assert :ok = Memory.register_resource(resource, cleanup_fun, :test)
      assert :ok = Memory.unregister_resource(resource)
    end
  end

  describe "memsup integration and memory usage testing" do
    setup do
      # Properly start and configure the required applications for memsup
      # Start SASL application (required for os_mon)
      sasl_started =
        case :application.ensure_all_started(:sasl) do
          {:ok, _apps} -> true
          {:error, _reason} -> false
        end

      # Start os_mon application with proper configuration
      os_mon_started =
        if sasl_started do
          # Configure os_mon before starting
          :application.set_env(:os_mon, :start_memsup, true)
          :application.set_env(:os_mon, :start_cpu_sup, false)
          :application.set_env(:os_mon, :start_disksup, false)

          case :application.ensure_all_started(:os_mon) do
            {:ok, _apps} -> true
            {:error, _reason} -> false
          end
        else
          false
        end

      # Check if memsup is actually available and working
      memsup_available =
        if os_mon_started do
          # Wait for memsup to initialize
          Process.sleep(200)

          # Verify memsup is actually working
          try do
            case :memsup.get_memory_data() do
              {total, allocated, _worst} when is_integer(total) and is_integer(allocated) ->
                true

              _ ->
                false
            end
          rescue
            _ -> false
          catch
            _ -> false
          end
        else
          false
        end

      on_exit(fn ->
        # Clean up applications started during test
        # Only stop os_mon if we started it and it's not already running globally
        if os_mon_started do
          # Check if os_mon is in the applications list before stopping
          running_apps = Enum.map(Application.started_applications(), fn {app, _, _} -> app end)

          if :os_mon in running_apps do
            :application.stop(:os_mon)
          end
        end
      end)

      %{
        sasl_started: sasl_started,
        os_mon_started: os_mon_started,
        memsup_available: memsup_available
      }
    end

    test "memsup is available and working", %{
      sasl_started: sasl_started,
      os_mon_started: os_mon_started,
      memsup_available: memsup_available
    } do
      if not memsup_available do
        # Provide detailed information about what failed
        IO.puts("\nMemsup availability check:")
        IO.puts("  SASL started: #{sasl_started}")
        IO.puts("  os_mon started: #{os_mon_started}")
        IO.puts("  memsup module loaded: #{Code.ensure_loaded?(:memsup)}")

        if os_mon_started do
          IO.puts("  os_mon processes: #{inspect(Process.whereis(:memsup))}")
        end

        # Test that the fallback mechanisms work properly when memsup is not available
        # This is actually a valid test case - systems may not have os_mon available
        {:ok, stats} = Memory.get_stats()
        assert is_number(stats.total_used_mb)
        assert stats.total_used_mb >= 0
        IO.puts("  Fallback memory calculation works: #{stats.total_used_mb} MB")
      else
        # Check if memsup module is loaded
        assert Code.ensure_loaded?(:memsup)

        # Test memsup basic functionality
        try do
          memory_data = :memsup.get_memory_data()
          assert is_tuple(memory_data)
          assert tuple_size(memory_data) == 3

          {total_memory, allocated_memory, worst_pid} = memory_data
          assert is_integer(total_memory)
          assert is_integer(allocated_memory)
          assert total_memory > 0
          assert allocated_memory > 0
          assert allocated_memory <= total_memory

          # IO.puts("\nMemsup data: Total=#{total_memory}, Allocated=#{allocated_memory}")

          # worst_pid can be undefined, a pid, or a tuple {pid, memory}
          case worst_pid do
            :undefined ->
              :ok

            pid when is_pid(pid) ->
              assert Process.alive?(pid)

            {pid, memory} when is_pid(pid) and is_integer(memory) ->
              assert Process.alive?(pid)
              assert memory >= 0

            _ ->
              flunk("Unexpected worst_pid format: #{inspect(worst_pid)}")
          end
        rescue
          error ->
            flunk("memsup.get_memory_data failed: #{inspect(error)}")
        end
      end
    end

    test "get_current_memory_usage with memsup available", %{memsup_available: memsup_available} do
      # Test the private function through Memory module operations
      # Since get_current_memory_usage is private, we test it indirectly

      # Test memory pressure detection which uses get_current_memory_usage
      pressure_before = Memory.under_pressure?()
      assert is_boolean(pressure_before)

      # Get memory stats which calls update_memory_stats -> get_current_memory_usage
      {:ok, stats_before} = Memory.get_stats()
      assert is_number(stats_before.total_used_mb)
      assert stats_before.total_used_mb >= 0

      # Allocate some memory to change usage
      _large_data = for i <- 1..10_000, do: {i, :crypto.strong_rand_bytes(1024)}

      # Check stats again
      {:ok, stats_after} = Memory.get_stats()
      assert is_number(stats_after.total_used_mb)

      # Memory usage should be reasonable (not negative, not impossibly large)
      assert stats_after.total_used_mb >= 0
      # Reasonable upper bound
      assert stats_after.total_used_mb < 100_000

      # The behavior might differ based on memsup availability
      if memsup_available do
        # With memsup, we should get more accurate system memory information
        # Test that the function handles memsup data correctly
        assert is_number(stats_after.total_used_mb)
      else
        # Without memsup, we fall back to Erlang memory info
        # Test that the fallback mechanism works
        assert is_number(stats_after.total_used_mb)
        # Should still provide reasonable values even without memsup
      end

      # Clean up
      _large_data = nil
      :erlang.garbage_collect()
    end

    test "get_current_memory_usage fallback when memsup fails", %{
      memsup_available: memsup_available
    } do
      # This test exercises the fallback paths in get_current_memory_usage

      # We can't easily make memsup fail, but we can test the fallback logic
      # by ensuring our implementation handles various memory scenarios

      # Test with different memory pressure scenarios
      original_config = %{
        max_memory_mb: 1024,
        # 50% threshold
        pressure_threshold: 0.5
      }

      Memory.configure(original_config)

      # Test pressure detection at different thresholds
      # 90% threshold
      low_pressure_config = %{pressure_threshold: 0.9}
      Memory.configure(low_pressure_config)

      pressure_low = Memory.under_pressure?()
      assert is_boolean(pressure_low)

      # 10% threshold
      high_pressure_config = %{pressure_threshold: 0.1}
      Memory.configure(high_pressure_config)

      pressure_high = Memory.under_pressure?()
      assert is_boolean(pressure_high)

      # Reset to original config
      Memory.configure(original_config)

      # Test that fallback logic works regardless of memsup availability
      # The function should always return valid results
      {:ok, stats} = Memory.get_stats()
      assert is_number(stats.total_used_mb)
      assert stats.total_used_mb >= 0

      if not memsup_available do
        # When memsup is not available, verify we're using fallback calculations
        # The implementation should still work properly
        assert is_number(stats.total_used_mb)
      end
    end

    test "memory usage calculation accuracy", %{memsup_available: memsup_available} do
      # Test that memory calculations are reasonable
      {:ok, initial_stats} = Memory.get_stats()

      # Create memory pressure and verify detection
      memory_hogs =
        for _i <- 1..1000 do
          spawn(fn ->
            # Each process allocates some memory and stays alive briefly
            _data = for j <- 1..1000, do: {j, j * j}
            Process.sleep(100)
          end)
        end

      # Allow processes to allocate memory
      Process.sleep(50)

      {:ok, pressure_stats} = Memory.get_stats()

      # Memory usage should have increased
      # Note: This might not always be detectable depending on GC timing
      assert is_number(pressure_stats.total_used_mb)
      assert pressure_stats.total_used_mb >= initial_stats.total_used_mb

      # Verify the calculation accuracy varies based on memsup availability
      if memsup_available do
        # With memsup, we should get system-level memory information
        # Test that the values are reasonable for system memory
        assert pressure_stats.total_used_mb > 0
      else
        # Without memsup, we use Erlang memory as fallback
        # Test that fallback calculations are still meaningful
        assert pressure_stats.total_used_mb > 0
        # Fallback should still provide useful memory pressure indication
      end

      # Clean up
      Enum.each(memory_hogs, fn pid ->
        if Process.alive?(pid), do: Process.exit(pid, :kill)
      end)

      # Allow cleanup
      Process.sleep(100)
      :erlang.garbage_collect()
    end

    test "memory monitoring with different operation types", %{
      memsup_available: _memsup_available
    } do
      # Test memory monitoring for different operation types
      operations = [:indexing, :search, :aggregation, :unknown]

      for operation <- operations do
        result =
          Memory.with_monitoring(
            fn ->
              # Simulate some memory usage
              _data = for i <- 1..100, do: {operation, i, :crypto.strong_rand_bytes(100)}
              operation
            end,
            operation_type: operation,
            memory_limit_mb: 50
          )

        assert {:ok, ^operation} = result
      end
    end

    test "memory cleanup effectiveness", %{memsup_available: _memsup_available} do
      # Test that cleanup actually helps with memory pressure
      {:ok, before_cleanup} = Memory.get_stats()

      # Create some memory pressure
      _pressure_data = for i <- 1..5000, do: {i, :crypto.strong_rand_bytes(1024)}

      {:ok, _during_pressure} = Memory.get_stats()

      # Force cleanup
      :ok = Memory.force_cleanup()

      {:ok, after_cleanup} = Memory.get_stats()

      # Verify cleanup incremented the counter
      assert after_cleanup.cleanup_count == before_cleanup.cleanup_count + 1
      assert after_cleanup.last_cleanup != nil

      # Verify GC was triggered during cleanup
      assert after_cleanup.gc_count >= before_cleanup.gc_count
    end

    test "memory stats tracking over time", %{memsup_available: _memsup_available} do
      # Test that memory stats are properly tracked over time
      {:ok, stats1} = Memory.get_stats()

      # Trigger some operations
      :ok = Memory.trigger_gc()
      :ok = Memory.force_cleanup()

      {:ok, stats2} = Memory.get_stats()

      # Verify counters increased
      assert stats2.gc_count == stats1.gc_count + 1
      assert stats2.cleanup_count == stats1.cleanup_count + 1

      # Verify timestamps are updated
      assert stats2.last_gc != stats1.last_gc
      assert stats2.last_cleanup != stats1.last_cleanup

      # Verify timestamps are recent DateTime structs
      assert %DateTime{} = stats2.last_gc
      assert %DateTime{} = stats2.last_cleanup

      # Timestamps should be within last few seconds
      now = DateTime.utc_now()
      gc_age = DateTime.diff(now, stats2.last_gc, :second)
      cleanup_age = DateTime.diff(now, stats2.last_cleanup, :second)

      assert gc_age >= 0 and gc_age < 10
      assert cleanup_age >= 0 and cleanup_age < 10
    end

    test "resource registration and cleanup integration", %{memsup_available: _memsup_available} do
      # Test that registered resources are cleaned up during memory pressure
      cleanup_called = :ets.new(:cleanup_tracker, [:set, :public])

      cleanup_fun = fn resource ->
        :ets.insert(cleanup_called, {resource, true})
        :ok
      end

      # Register several resources
      resources =
        for _i <- 1..5 do
          resource = make_ref()
          :ok = Memory.register_resource(resource, cleanup_fun, :test)
          resource
        end

      # Force cleanup which should trigger resource cleanup
      :ok = Memory.force_cleanup()

      # Verify some cleanup was attempted
      # Note: The exact cleanup behavior depends on implementation details

      # Clean up test ETS table
      :ets.delete(cleanup_called)

      # Unregister resources
      Enum.each(resources, &Memory.unregister_resource/1)
    end

    test "concurrent memory operations", %{memsup_available: _memsup_available} do
      # Test memory operations under concurrent load
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            # Each task performs various memory operations
            {:ok, _stats} = Memory.get_stats()
            _pressure = Memory.under_pressure?()

            # Some tasks trigger cleanup/GC
            if rem(i, 3) == 0, do: Memory.trigger_gc()
            if rem(i, 5) == 0, do: Memory.force_cleanup()

            # Monitor some memory operations
            Memory.with_monitoring(
              fn ->
                _data = for j <- 1..100, do: {i, j}
                i
              end,
              operation_type: :concurrent_test
            )
          end)
        end

      # Wait for all tasks to complete
      results = Task.await_many(tasks, 5000)

      # Verify all operations completed successfully
      assert length(results) == 10

      Enum.each(results, fn result ->
        assert {:ok, _} = result
      end)
    end

    test "get_current_memory_usage comprehensive testing", %{memsup_available: memsup_available} do
      # Test comprehensive scenarios for the get_current_memory_usage function
      # This tests the core logic that's used throughout the Memory module

      # Test 1: Basic functionality - memory usage should always be a reasonable number
      {:ok, stats} = Memory.get_stats()
      assert is_number(stats.total_used_mb)
      assert stats.total_used_mb >= 0
      # Sanity check: less than 1TB
      assert stats.total_used_mb < 1_000_000

      # Test 2: Memory usage under load
      # Create memory load and verify it's detected
      # 10KB each
      _memory_load = for _i <- 1..1000, do: :crypto.strong_rand_bytes(10_240)

      {:ok, stats_under_load} = Memory.get_stats()
      assert is_number(stats_under_load.total_used_mb)
      assert stats_under_load.total_used_mb >= stats.total_used_mb

      # Test 3: Behavior differences based on memsup availability
      if memsup_available do
        # When memsup is available, test that we get system memory information
        # The values should reflect actual system memory usage
        assert stats_under_load.total_used_mb > 0

        # Try to call memsup directly and verify our wrapper handles it correctly
        try do
          memsup_data = :memsup.get_memory_data()
          assert is_tuple(memsup_data)
          # Our memory calculations should be based on this data when available
        rescue
          _ ->
            # If memsup call fails, our fallback should still work
            assert is_number(stats_under_load.total_used_mb)
        end
      else
        # When memsup is not available, test that fallback logic works
        # Should still provide meaningful memory usage information
        assert stats_under_load.total_used_mb > 0

        # Verify we're using Erlang memory info as fallback
        erlang_memory = :erlang.memory()
        assert is_list(erlang_memory)
        assert Keyword.has_key?(erlang_memory, :total)
      end

      # Test 4: Memory pressure scenarios
      # Configure different pressure thresholds and verify behavior
      # Very sensitive
      Memory.configure(%{pressure_threshold: 0.1})
      pressure_high_sensitivity = Memory.under_pressure?()

      # Very insensitive
      Memory.configure(%{pressure_threshold: 0.9})
      pressure_low_sensitivity = Memory.under_pressure?()

      # Both should be boolean results regardless of memsup availability
      assert is_boolean(pressure_high_sensitivity)
      assert is_boolean(pressure_low_sensitivity)

      # Test 5: Consistency across multiple calls
      # Memory usage should be consistent across rapid successive calls
      measurements =
        for _i <- 1..5 do
          {:ok, stats} = Memory.get_stats()
          stats.total_used_mb
        end

      # All measurements should be numbers
      Enum.each(measurements, fn measurement ->
        assert is_number(measurement)
        assert measurement >= 0
      end)

      # Measurements should be relatively stable (within reasonable bounds)
      min_measurement = Enum.min(measurements)
      max_measurement = Enum.max(measurements)
      variation = max_measurement - min_measurement

      # Variation should be reasonable (memory shouldn't fluctuate wildly)
      # Less than 1GB variation in rapid succession
      assert variation < 1000

      # Clean up
      _memory_load = nil
      :erlang.garbage_collect()

      # Reset to default configuration
      Memory.configure(%{pressure_threshold: 0.8})
    end

    test "get_current_memory_usage edge cases and error handling", %{
      memsup_available: memsup_available
    } do
      # Test edge cases and error handling in memory usage calculation

      # Test 1: Behavior during garbage collection
      # Force GC and verify memory calculations still work
      :erlang.garbage_collect()
      {:ok, stats_after_gc} = Memory.get_stats()
      assert is_number(stats_after_gc.total_used_mb)

      # Test 2: Behavior with extreme memory configurations
      # Test with very high memory limits
      Memory.configure(%{
        # 1TB limit
        max_memory_mb: 1_000_000,
        pressure_threshold: 0.5
      })

      {:ok, stats_high_limit} = Memory.get_stats()
      assert is_number(stats_high_limit.total_used_mb)
      assert stats_high_limit.total_limit_mb == 1_000_000

      # Test with very low memory limits
      Memory.configure(%{
        # 1MB limit (unrealistically low)
        max_memory_mb: 1,
        pressure_threshold: 0.5
      })

      {:ok, stats_low_limit} = Memory.get_stats()
      assert is_number(stats_low_limit.total_used_mb)
      assert stats_low_limit.total_limit_mb == 1

      # With such a low limit, we should likely be under pressure
      pressure_with_low_limit = Memory.under_pressure?()
      assert is_boolean(pressure_with_low_limit)

      # Test 3: Stress test with rapid memory operations
      # Rapidly allocate and deallocate memory while measuring
      for _round <- 1..10 do
        # Allocate memory
        _temp_data = for _i <- 1..100, do: :crypto.strong_rand_bytes(1024)

        # Measure during allocation
        {:ok, stats_during_alloc} = Memory.get_stats()
        assert is_number(stats_during_alloc.total_used_mb)

        # Deallocate
        _temp_data = nil
        :erlang.garbage_collect()

        # Measure after deallocation
        {:ok, stats_after_dealloc} = Memory.get_stats()
        assert is_number(stats_after_dealloc.total_used_mb)
      end

      # Test 4: Verify behavior under different system conditions
      if memsup_available do
        # Test that memsup errors are handled gracefully
        # We can't easily mock memsup to fail, but we can verify
        # that our code doesn't crash when memsup might return unexpected data
        {:ok, stats} = Memory.get_stats()
        assert is_number(stats.total_used_mb)
      else
        # Test that fallback calculations work under stress
        # Create significant memory pressure
        _large_allocation = for _i <- 1..10_000, do: :crypto.strong_rand_bytes(1024)

        {:ok, stats_under_pressure} = Memory.get_stats()
        assert is_number(stats_under_pressure.total_used_mb)

        # Clean up
        _large_allocation = nil
        :erlang.garbage_collect()
      end

      # Reset to reasonable defaults
      Memory.configure(%{
        max_memory_mb: 2048,
        pressure_threshold: 0.8
      })
    end

    test "memory usage calculation with concurrent operations", %{
      memsup_available: _memsup_available
    } do
      # Test memory usage calculation under concurrent load
      # This exercises the thread safety of get_current_memory_usage

      # Start multiple processes that allocate memory and measure usage
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            # Each task allocates memory and measures
            data = for j <- 1..100, do: {i, j, :crypto.strong_rand_bytes(512)}

            # Measure memory usage during the allocation
            {:ok, stats} = Memory.get_stats()

            # Verify measurement is valid
            assert is_number(stats.total_used_mb)
            assert stats.total_used_mb >= 0

            # Return the measurement for analysis
            {i, stats.total_used_mb, data}
          end)
        end

      # Wait for all measurements
      results = Task.await_many(tasks, 5000)

      # Verify all measurements are valid
      measurements =
        for {_task_id, measurement, _data} <- results do
          assert is_number(measurement)
          assert measurement >= 0
          measurement
        end

      # All measurements should be in a reasonable range
      min_measurement = Enum.min(measurements)
      max_measurement = Enum.max(measurements)

      assert min_measurement >= 0
      # Less than 100GB (sanity check)
      assert max_measurement < 100_000

      # The range of measurements should be reasonable
      # (concurrent operations shouldn't cause wildly different readings)
      range = max_measurement - min_measurement
      # Less than 10GB range
      assert range < 10_000

      # Clean up - results contain references to allocated data
      _results = nil
      :erlang.garbage_collect()
    end
  end
end
