defmodule TantivyEx.WrapperConcurrencyTest do
  @moduledoc """
  Tests for concurrent access to TantivyEx wrapper functions.

  These tests specifically target the wrapper layer to ensure proper
  error handling, resource management, and thread safety at the NIF boundary.

  Note: Tantivy enforces single-writer locks per index, so tests respect
  this constraint using separate indices for multiple writers.
  """

  use ExUnit.Case, async: false
  require Logger

  alias TantivyEx.{
    Schema,
    Index,
    IndexWriter,
    Searcher,
    Query,
    CustomCollector,
    ReaderManager,
    IndexWarming
  }

  alias TantivyEx.Native

  @test_timeout 20_000

  describe "wrapper function concurrent access" do
    test "concurrent schema operations" do
      # Test concurrent schema creation and manipulation
      schema_tasks =
        1..10
        |> Enum.map(fn task_id ->
          Task.async(fn ->
            # Each task creates its own schema
            schema = Schema.new()

            # Add fields concurrently
            schema = Schema.add_text_field(schema, "title_#{task_id}", :text_stored)
            schema = Schema.add_u64_field(schema, "id_#{task_id}", :indexed_stored)
            schema = Schema.add_f64_field(schema, "score_#{task_id}", :indexed_stored)

            # Test schema introspection
            field_names = Schema.get_field_names(schema)

            field_info_results =
              field_names
              |> Enum.map(fn field_name ->
                Schema.get_field_type(schema, field_name)
              end)

            {task_id, length(field_names), length(field_info_results)}
          end)
        end)

      results = Task.await_many(schema_tasks, @test_timeout)

      # Verify all schema operations completed successfully
      Enum.each(results, fn {task_id, field_count, info_count} ->
        assert field_count == 3, "Task #{task_id} should have 3 fields"
        assert info_count == 3, "Task #{task_id} should get info for all fields"
      end)
    end

    test "concurrent index creation and access" do
      schema = create_test_schema()

      # Test concurrent index creation
      index_tasks =
        1..8
        |> Enum.map(fn task_id ->
          Task.async(fn ->
            case rem(task_id, 2) do
              0 ->
                # RAM index
                case Index.create_in_ram(schema) do
                  {:ok, index} ->
                    # Verify we can use the index
                    case IndexWriter.new(index, 1_000_000) do
                      {:ok, _writer} -> {:ram_success, task_id}
                      {:error, reason} -> {:ram_writer_error, task_id, reason}
                    end

                  {:error, reason} ->
                    {:ram_index_error, task_id, reason}
                end

              1 ->
                # Directory index (using temporary directory)
                temp_dir =
                  Path.join([
                    System.tmp_dir!(),
                    "tantivy_test_#{task_id}_#{:os.system_time(:microsecond)}"
                  ])

                try do
                  # Ensure directory exists and is empty
                  if File.exists?(temp_dir) do
                    File.rm_rf!(temp_dir)
                  end

                  :ok = File.mkdir_p!(temp_dir)

                  case Index.create_in_dir(temp_dir, schema) do
                    {:ok, index} ->
                      case IndexWriter.new(index, 1_000_000) do
                        {:ok, _writer} ->
                          # Cleanup
                          File.rm_rf!(temp_dir)
                          {:dir_success, task_id}

                        {:error, reason} ->
                          File.rm_rf!(temp_dir)

                          {:dir_writer_error, task_id,
                           "Failed to create writer: #{inspect(reason)}"}
                      end

                    {:error, reason} ->
                      File.rm_rf!(temp_dir)
                      {:dir_index_error, task_id, "Failed to create index: #{inspect(reason)}"}
                  end
                rescue
                  e ->
                    File.rm_rf!(temp_dir)
                    {:dir_exception, task_id, "Exception: #{inspect(e)}"}
                end
            end
          end)
        end)

      results = Task.await_many(index_tasks, @test_timeout)

      # Count successful operations - handle both 2-tuple and 3-tuple results
      ram_successes =
        Enum.count(results, fn
          {:ram_success, _id} -> true
          _ -> false
        end)

      dir_successes =
        Enum.count(results, fn
          {:dir_success, _id} -> true
          _ -> false
        end)

      # Log any errors for debugging
      errors =
        Enum.filter(results, fn
          {:ram_success, _} -> false
          {:dir_success, _} -> false
          _error -> true
        end)

      if length(errors) > 0 do
        Logger.warning("Index creation errors: #{inspect(errors)}")
      end

      assert ram_successes == 4,
             "Should have 4 successful RAM index creations, got #{ram_successes}"

      assert dir_successes == 4,
             "Should have 4 successful directory index creations, got #{dir_successes}"
    end

    test "concurrent document operations with wrapper error handling" do
      schema = create_test_schema()

      # Test concurrent document operations with separate indices to respect single-writer constraint
      doc_tasks =
        1..12
        |> Enum.map(fn task_id ->
          Task.async(fn ->
            # Create separate index for each task to avoid writer conflicts
            case Index.create_in_ram(schema) do
              {:ok, index} ->
                case IndexWriter.new(index, 1_000_000) do
                  {:ok, writer} ->
                    results =
                      1..15
                      |> Enum.map(fn doc_id ->
                        doc = %{
                          "id" => task_id * 100 + doc_id,
                          "title" => "Document #{task_id}-#{doc_id}",
                          "content" => "Content for #{task_id}-#{doc_id}",
                          "category" => "concurrent_test",
                          "score" => (task_id + doc_id) * 1.0
                        }

                        # Test both successful and potentially problematic operations
                        case rem(doc_id, 10) do
                          0 ->
                            # Test with invalid document occasionally
                            invalid_doc = Map.put(doc, "invalid_field", "should_be_ignored")
                            IndexWriter.add_document(writer, invalid_doc)

                          _ ->
                            # Normal document
                            IndexWriter.add_document(writer, doc)
                        end
                      end)

                    # Commit the batch
                    commit_result = IndexWriter.commit(writer)

                    successful_adds = Enum.count(results, fn result -> result == :ok end)
                    {task_id, successful_adds, commit_result}

                  {:error, reason} ->
                    {task_id, 0, {:writer_error, reason}}
                end

              {:error, reason} ->
                {task_id, 0, {:index_error, reason}}
            end
          end)
        end)

      results = Task.await_many(doc_tasks, @test_timeout)

      # Verify operations completed (allowing for some variation in success counts)
      total_successful_tasks =
        results
        |> Enum.count(fn
          {_task_id, adds, :ok} when adds > 10 -> true
          _ -> false
        end)

      assert total_successful_tasks >= 10,
             "At least 10 tasks should have completed successfully"
    end

    test "concurrent search operations with different wrapper patterns" do
      # Setup index with data
      schema = create_test_schema()
      {:ok, index} = Index.create_in_ram(schema)
      setup_test_data(index, 100)

      # Define search patterns that should work concurrently
      search_patterns = [
        {"basic_term", fn -> Query.term(schema, "category", "test") end},
        {"range_query", fn -> Query.range_u64(schema, "id", 10, 90) end},
        {"all_docs", fn -> Query.all() end}
      ]

      # Start concurrent search tasks
      search_tasks =
        1..8
        |> Enum.map(fn task_id ->
          Task.async(fn ->
            {:ok, searcher} = Searcher.new(index)

            results =
              1..15
              |> Enum.map(fn _iteration ->
                {pattern_name, query_fn} = Enum.random(search_patterns)

                case query_fn.() do
                  {:ok, query} ->
                    case Searcher.search(searcher, query, 25) do
                      {:ok, search_results} ->
                        {pattern_name, length(search_results), :success}

                      {:error, reason} ->
                        {pattern_name, 0, {:error, reason}}
                    end

                  {:error, reason} ->
                    {pattern_name, 0, {:query_error, reason}}
                end
              end)

            successful_searches =
              results
              |> Enum.count(fn {_pattern, _count, status} -> status == :success end)

            {task_id, successful_searches}
          end)
        end)

      search_results = Task.await_many(search_tasks, @test_timeout)

      # Verify searches completed successfully
      Enum.each(search_results, fn {task_id, successful_count} ->
        assert successful_count >= 12,
               "Task #{task_id} should have at least 12 successful searches, got #{successful_count}"
      end)
    end

    test "concurrent wrapper module access" do
      # Test concurrent access to different wrapper modules
      schema = create_test_schema()
      {:ok, index} = Index.create_in_ram(schema)
      setup_test_data(index, 50)

      module_tasks = [
        # CustomCollector operations
        Task.async(fn ->
          results =
            1..10
            |> Enum.map(fn _iteration ->
              case CustomCollector.new() do
                {:ok, _collector} -> :collector_success
                {:error, :not_implemented} -> :collector_not_implemented
                {:error, :invalid_parameters} -> :collector_invalid_params
                {:error, reason} -> {:collector_error, reason}
              end
            end)

          {:custom_collector, results}
        end),

        # ReaderManager operations
        Task.async(fn ->
          results =
            1..10
            |> Enum.map(fn iteration ->
              case ReaderManager.new() do
                {:ok, manager} ->
                  # Test create_policy operation (this function exists)
                  try do
                    case Native.reader_manager_create_policy(
                           manager,
                           "test_policy_#{iteration}",
                           "manual",
                           3600,
                           60,
                           false,
                           false,
                           false
                         ) do
                      :ok -> :manager_success
                      error -> {:manager_policy_error, error}
                    end
                  rescue
                    ArgumentError -> :manager_invalid_params
                    ErlangError -> :manager_not_implemented
                  end

                {:error, :not_implemented} ->
                  :manager_not_implemented

                {:error, :invalid_parameters} ->
                  :manager_invalid_params

                {:error, reason} ->
                  {:manager_error, reason}
              end
            end)

          {:reader_manager, results}
        end),

        # IndexWarming operations
        Task.async(fn ->
          results =
            1..10
            |> Enum.map(fn _iteration ->
              case IndexWarming.new() do
                {:ok, warming} ->
                  # Test configure operation
                  case IndexWarming.configure(warming, 100, 300, "lazy", "lru", true) do
                    :ok -> :warming_success
                    {:error, reason} -> {:warming_config_error, reason}
                  end

                {:error, :not_implemented} ->
                  :warming_not_implemented

                {:error, :invalid_parameters} ->
                  :warming_invalid_params

                {:error, reason} ->
                  {:warming_error, reason}
              end
            end)

          # Add debug logging
          Logger.debug("IndexWarming results: #{inspect(results)}")

          {:index_warming, results}
        end),

        # Core operations (should always work)
        Task.async(fn ->
          {:ok, searcher} = Searcher.new(index)

          results =
            1..20
            |> Enum.map(fn _iteration ->
              {:ok, query} = Query.all()

              case Searcher.search(searcher, query, 10) do
                {:ok, _results} -> :core_success
                {:error, reason} -> {:core_error, reason}
              end
            end)

          {:core_operations, results}
        end)
      ]

      results = Task.await_many(module_tasks, @test_timeout)

      # Debug logging to see actual results
      Logger.debug("All module results: #{inspect(results)}")

      # Verify each module type
      Enum.each(results, fn {module_type, module_results} ->
        case module_type do
          :custom_collector ->
            # Should handle not implemented gracefully
            success_count =
              Enum.count(module_results, fn result ->
                result in [
                  :collector_success,
                  :collector_not_implemented,
                  :collector_invalid_params
                ]
              end)

            assert success_count == 10, "CustomCollector should handle all calls gracefully"

          :reader_manager ->
            # Should handle policy creation or not implemented gracefully
            success_count =
              Enum.count(module_results, fn result ->
                result in [:manager_success, :manager_not_implemented, :manager_invalid_params]
              end)

            assert success_count >= 8, "ReaderManager should handle most calls gracefully"

          :index_warming ->
            # Should handle not implemented gracefully
            success_count =
              Enum.count(module_results, fn result ->
                result in [:warming_success, :warming_not_implemented, :warming_invalid_params]
              end)

            # Debug logging to see what we actually got
            failure_results =
              Enum.reject(module_results, fn result ->
                result in [:warming_success, :warming_not_implemented, :warming_invalid_params]
              end)

            Logger.debug("IndexWarming failures: #{inspect(failure_results)}")

            assert success_count >= 8,
                   "IndexWarming should handle most calls gracefully, got #{success_count}/10, failures: #{inspect(failure_results)}"

          :core_operations ->
            # Core operations should always succeed
            success_count = Enum.count(module_results, fn result -> result == :core_success end)
            assert success_count == 20, "Core operations should always succeed"
        end
      end)
    end

    test "resource cleanup under concurrent stress" do
      schema = create_test_schema()

      # Create many short-lived resources concurrently
      cleanup_tasks =
        1..25
        |> Enum.map(fn task_id ->
          Task.async(fn ->
            operations =
              1..10
              |> Enum.map(fn op_id ->
                # Create index
                case Index.create_in_ram(schema) do
                  {:ok, index} ->
                    # Create writer
                    case IndexWriter.new(index, 500_000) do
                      {:ok, writer} ->
                        # Add a few documents
                        doc = %{
                          "id" => task_id * 100 + op_id,
                          "title" => "Resource test #{task_id}-#{op_id}",
                          "content" => "Content #{task_id}-#{op_id}",
                          "category" => "cleanup_test",
                          "score" => op_id * 1.0
                        }

                        add_result = IndexWriter.add_document(writer, doc)
                        commit_result = IndexWriter.commit(writer)

                        # Create searcher
                        case Searcher.new(index) do
                          {:ok, searcher} ->
                            {:ok, query} = Query.all()

                            case Searcher.search(searcher, query, 10) do
                              {:ok, _results} ->
                                case {add_result, commit_result} do
                                  {:ok, :ok} -> :operation_success
                                  _ -> :operation_partial_success
                                end

                              {:error, _} ->
                                :operation_search_failed
                            end

                          {:error, _} ->
                            :operation_searcher_failed
                        end

                      {:error, _} ->
                        :operation_writer_failed
                    end

                  {:error, _} ->
                    :operation_index_failed
                end
              end)

            # Count successful operations
            successful_ops = Enum.count(operations, fn result -> result == :operation_success end)
            {task_id, successful_ops}
          end)
        end)

      results = Task.await_many(cleanup_tasks, @test_timeout)

      # Verify operations completed successfully
      total_successful_tasks =
        results
        |> Enum.count(fn {_task_id, successful_ops} -> successful_ops >= 8 end)

      assert total_successful_tasks >= 20,
             "At least 20 tasks should have completed 8+ operations successfully"

      # Force garbage collection to test cleanup
      :erlang.garbage_collect()
      Process.sleep(100)

      # Verify we can still create new resources after cleanup
      {:ok, _test_index} = Index.create_in_ram(schema)
    end

    test "concurrent disk index operations with wrappers" do
      schema = create_test_schema()

      # Test various wrapper operations on disk indices
      disk_tasks =
        1..4
        |> Enum.map(fn task_id ->
          Task.async(fn ->
            temp_dir = create_temp_dir("wrapper_disk_#{task_id}")

            try do
              {:ok, index} = Index.create_in_dir(temp_dir, schema)
              {:ok, writer} = IndexWriter.new(index, 2_000_000)

              # Add test documents
              1..8
              |> Enum.each(fn doc_id ->
                doc = %{
                  "id" => task_id * 100 + doc_id,
                  "title" => "Disk Document #{task_id}-#{doc_id}",
                  "content" => "Test content for disk index #{task_id}"
                }

                IndexWriter.add_document(writer, doc)
              end)

              IndexWriter.commit(writer)

              # Test search operations
              {:ok, searcher} = Searcher.new(index)
              {:ok, query} = Query.all()
              {:ok, results} = Searcher.search(searcher, query, 20)

              {:disk_success, task_id, length(results)}
            rescue
              e ->
                {:disk_error, task_id, "Exception: #{inspect(e)}"}
            after
              File.rm_rf(temp_dir)
            end
          end)
        end)

      results = Task.await_many(disk_tasks, @test_timeout)

      # Verify all disk operations succeeded
      successes =
        Enum.count(results, fn
          {:disk_success, _id, _count} -> true
          _ -> false
        end)

      assert successes == 4, "All 4 disk index operations should succeed, got #{successes}"

      # Verify document counts
      Enum.each(results, fn
        {:disk_success, task_id, doc_count} ->
          assert doc_count == 8, "Disk index #{task_id} should have 8 documents"

        _ ->
          :ok
      end)
    end
  end

  # Helper functions

  defp create_temp_dir(prefix) do
    timestamp = System.system_time(:microsecond)
    temp_dir = Path.join([System.tmp_dir!(), "tantivy_wrapper_#{prefix}_#{timestamp}"])

    # Ensure directory is clean
    if File.exists?(temp_dir) do
      File.rm_rf!(temp_dir)
    end

    File.mkdir_p!(temp_dir)

    temp_dir
  end

  defp create_test_schema do
    schema = Schema.new()
    schema = Schema.add_u64_field(schema, "id", :indexed_stored)
    schema = Schema.add_text_field(schema, "title", :text_stored)
    schema = Schema.add_text_field(schema, "content", :text)
    schema = Schema.add_text_field(schema, "category", :text_stored)
    schema = Schema.add_f64_field(schema, "score", :indexed_stored)
    schema
  end

  defp setup_test_data(index, doc_count) do
    {:ok, writer} = IndexWriter.new(index, 10_000_000)

    1..doc_count
    |> Enum.each(fn i ->
      doc = %{
        "id" => i,
        "title" => "Test Document #{i}",
        "content" => "Test content for document #{i} with searchable terms",
        "category" => "test",
        "score" => i * 2.0
      }

      IndexWriter.add_document(writer, doc)
    end)

    IndexWriter.commit(writer)
  end
end
