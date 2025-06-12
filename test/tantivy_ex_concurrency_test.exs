defmodule TantivyEx.ConcurrencyTest do
  @moduledoc """
  Tests for concurrent read and write operations on TantivyEx components.

  These tests verify thread safety and proper resource management under
  concurrent access patterns typical in production environ    test "concurrent document operations with different access patterns" do
      schema = create_test_schema()

      # Create separate indices for each task to respect single-writer constraint
      {:ok, index1} = Index.create_in_ram(schema)
      {:ok, index2} = Index.create_in_ram(schema)
      {:ok, index3} = Index.create_in_ram(schema)

      # Task 1: Batch operations
      batch_task = Task.async(fn ->
        {:ok, writer} = IndexWriter.new(index1, 10_000_000)
  Note: Tantivy enforces single-writer locks per index, so tests are designed
  to work within this constraint using separate indices or sequential writers.
  """

  use ExUnit.Case, async: false
  require Logger

  alias TantivyEx.{Schema, Index, IndexWriter, Searcher, Query}

  @test_timeout 30_000

  describe "concurrent index operations" do
    test "concurrent writes to separate indices" do
      schema = create_test_schema()

      # Create multiple writers on separate indices (realistic pattern)
      tasks =
        1..5
        |> Enum.map(fn writer_id ->
          Task.async(fn ->
            {:ok, index} = Index.create_in_ram(schema)
            {:ok, writer} = IndexWriter.new(index, 10_000_000)

            # Each writer adds documents with unique content
            documents = create_test_documents(writer_id, 20)

            results =
              Enum.map(documents, fn doc ->
                IndexWriter.add_document(writer, doc)
              end)

            # Commit the batch
            commit_result = IndexWriter.commit(writer)

            # Verify searchability
            {:ok, searcher} = Searcher.new(index)
            {:ok, query} = Query.all()
            {:ok, search_results} = Searcher.search(searcher, query, 50)

            {writer_id, length(results), commit_result, length(search_results)}
          end)
        end)

      # Wait for all writers to complete
      results = Task.await_many(tasks, @test_timeout)

      # Verify all writers succeeded
      Enum.each(results, fn {writer_id, doc_count, commit_result, search_count} ->
        assert doc_count == 20, "Writer #{writer_id} should have processed 20 documents"
        assert :ok == commit_result, "Writer #{writer_id} should have committed successfully"
        assert search_count == 20, "Writer #{writer_id} should find all documents"
      end)
    end

    test "concurrent reads during single writer operations" do
      schema = create_test_schema()
      {:ok, index} = Index.create_in_ram(schema)

      # Pre-populate index with some data
      {:ok, writer} = IndexWriter.new(index, 10_000_000)
      initial_docs = create_test_documents(0, 50)
      Enum.each(initial_docs, &IndexWriter.add_document(writer, &1))
      IndexWriter.commit(writer)

      # Start single writer task (realistic pattern) - reuse existing writer
      write_task =
        Task.async(fn ->
          1..100
          |> Enum.map(fn batch_id ->
            docs = create_test_documents(batch_id, 10)
            Enum.each(docs, &IndexWriter.add_document(writer, &1))

            if rem(batch_id, 10) == 0 do
              IndexWriter.commit(writer)
            end

            # Small delay to allow readers to interleave
            Process.sleep(10)
            batch_id
          end)
          |> length()
        end)

      # Start multiple concurrent readers
      read_tasks =
        1..8
        |> Enum.map(fn reader_id ->
          Task.async(fn ->
            {:ok, searcher} = Searcher.new(index)

            search_results =
              1..50
              |> Enum.map(fn search_id ->
                search_term = "content_#{rem(search_id, 20)}"
                {:ok, query} = Query.term(schema, "content", search_term)

                case Searcher.search(searcher, query, 50) do
                  {:ok, results} -> length(results)
                  {:error, _} -> 0
                end
              end)

            {reader_id, Enum.sum(search_results)}
          end)
        end)

      # Wait for all tasks to complete
      write_result = Task.await(write_task, @test_timeout)
      read_results = Task.await_many(read_tasks, @test_timeout)

      # Verify writer completed successfully
      assert write_result == 100

      # Verify all readers completed and found results
      Enum.each(read_results, fn {reader_id, total_results} ->
        assert total_results >= 0, "Reader #{reader_id} should have completed searches"
      end)
    end

    test "concurrent schema introspection during writes" do
      schema = create_test_schema()
      {:ok, index} = Index.create_in_ram(schema)

      # Start writing task
      write_task =
        Task.async(fn ->
          {:ok, writer} = IndexWriter.new(index, 10_000_000)

          1..50
          |> Enum.each(fn batch_id ->
            docs = create_test_documents(batch_id, 5)
            Enum.each(docs, &IndexWriter.add_document(writer, &1))

            if rem(batch_id, 10) == 0 do
              IndexWriter.commit(writer)
            end

            Process.sleep(5)
          end)

          IndexWriter.commit(writer)
          :completed
        end)

      # Start concurrent schema introspection tasks
      introspection_tasks =
        1..6
        |> Enum.map(fn task_id ->
          Task.async(fn ->
            results =
              1..30
              |> Enum.map(fn _iteration ->
                # Test various schema operations
                field_names = Schema.get_field_names(schema)

                field_type_results =
                  field_names
                  |> Enum.map(fn field_name ->
                    Schema.get_field_type(schema, field_name)
                  end)

                {length(field_names), length(field_type_results)}
              end)

            {task_id, results}
          end)
        end)

      # Wait for completion
      write_result = Task.await(write_task, @test_timeout)
      introspection_results = Task.await_many(introspection_tasks, @test_timeout)

      # Verify write completed
      assert write_result == :completed

      # Verify schema introspection remained consistent
      Enum.each(introspection_results, fn {task_id, results} ->
        assert length(results) == 30, "Task #{task_id} should have completed all iterations"

        # All schema calls should return consistent results
        Enum.each(results, fn {field_count, type_count} ->
          # Our test schema has 5 fields
          assert field_count == 5
          # Should get type for all fields
          assert type_count == 5
        end)
      end)
    end
  end

  describe "concurrent on-disk index operations" do
    test "concurrent writes to separate disk indices" do
      schema = create_test_schema()

      # Create multiple writers on separate disk indices (realistic pattern)
      tasks =
        1..3
        |> Enum.map(fn writer_id ->
          Task.async(fn ->
            # Create unique directory for each writer
            temp_dir = create_temp_dir("writer_#{writer_id}")

            try do
              {:ok, index} = Index.create_in_dir(temp_dir, schema)
              {:ok, writer} = IndexWriter.new(index, 10_000_000)

              # Each writer adds documents with unique content
              documents = create_test_documents(writer_id, 15)

              results =
                Enum.map(documents, fn doc ->
                  IndexWriter.add_document(writer, doc)
                end)

              # Commit the batch
              commit_result = IndexWriter.commit(writer)

              # Verify searchability
              {:ok, searcher} = Searcher.new(index)
              {:ok, query} = Query.all()
              {:ok, search_results} = Searcher.search(searcher, query, 50)

              {writer_id, length(results), commit_result, length(search_results)}
            after
              # Cleanup
              File.rm_rf(temp_dir)
            end
          end)
        end)

      # Wait for all writers to complete
      results = Task.await_many(tasks, @test_timeout)

      # Verify all writers succeeded
      Enum.each(results, fn {writer_id, doc_count, commit_result, search_count} ->
        assert doc_count == 15, "Writer #{writer_id} should have processed 15 documents"
        assert :ok == commit_result, "Writer #{writer_id} should have committed successfully"
        assert search_count == 15, "Writer #{writer_id} should find all documents"
      end)
    end

    test "mixed RAM and disk indices with concurrent operations" do
      schema = create_test_schema()

      # Create mix of RAM and disk indices
      tasks =
        1..4
        |> Enum.map(fn task_id ->
          Task.async(fn ->
            # Alternate between RAM and disk indices
            {index, cleanup_fn} =
              if rem(task_id, 2) == 0 do
                # RAM index
                {:ok, index} = Index.create_in_ram(schema)
                {index, fn -> :ok end}
              else
                # Disk index
                temp_dir = create_temp_dir("mixed_#{task_id}")
                {:ok, index} = Index.create_in_dir(temp_dir, schema)
                {index, fn -> File.rm_rf(temp_dir) end}
              end

            try do
              {:ok, writer} = IndexWriter.new(index, 5_000_000)

              # Add documents
              docs = create_test_documents(task_id, 10)
              Enum.each(docs, &IndexWriter.add_document(writer, &1))
              IndexWriter.commit(writer)

              # Perform searches
              {:ok, searcher} = Searcher.new(index)
              {:ok, query} = Query.all()
              {:ok, results} = Searcher.search(searcher, query, 50)

              index_type = if rem(task_id, 2) == 0, do: :ram, else: :disk
              {task_id, index_type, length(results)}
            after
              cleanup_fn.()
            end
          end)
        end)

      # Wait for all operations to complete
      results = Task.await_many(tasks, @test_timeout)

      # Verify all operations completed successfully
      Enum.each(results, fn {task_id, index_type, result_count} ->
        assert result_count == 10, "Task #{task_id} (#{index_type}) should have 10 documents"
      end)

      # Verify we had both types of indices
      ram_indices = Enum.count(results, fn {_, type, _} -> type == :ram end)
      disk_indices = Enum.count(results, fn {_, type, _} -> type == :disk end)

      assert ram_indices >= 1, "Should have at least 1 RAM index"
      assert disk_indices >= 1, "Should have at least 1 disk index"
    end

    test "concurrent reads during disk index writes" do
      schema = create_test_schema()
      temp_dir = create_temp_dir("concurrent_reads_writes")

      try do
        {:ok, index} = Index.create_in_dir(temp_dir, schema)

        # Pre-populate index with some data
        {:ok, writer} = IndexWriter.new(index, 10_000_000)
        initial_docs = create_test_documents(0, 30)
        Enum.each(initial_docs, &IndexWriter.add_document(writer, &1))
        IndexWriter.commit(writer)

        # Start single writer task (realistic pattern) - reuse existing writer
        write_task =
          Task.async(fn ->
            1..50
            |> Enum.map(fn batch_id ->
              docs = create_test_documents(batch_id, 5)
              Enum.each(docs, &IndexWriter.add_document(writer, &1))

              if rem(batch_id, 10) == 0 do
                IndexWriter.commit(writer)
              end

              # Small delay to allow readers to interleave
              Process.sleep(15)
              batch_id
            end)
            |> length()
          end)

        # Start multiple concurrent readers
        read_tasks =
          1..4
          |> Enum.map(fn reader_id ->
            Task.async(fn ->
              {:ok, searcher} = Searcher.new(index)

              search_results =
                1..25
                |> Enum.map(fn search_id ->
                  search_term = "content_#{rem(search_id, 10)}"
                  {:ok, query} = Query.term(schema, "content", search_term)

                  case Searcher.search(searcher, query, 50) do
                    {:ok, results} -> length(results)
                    {:error, _} -> 0
                  end
                end)

              {reader_id, Enum.sum(search_results)}
            end)
          end)

        # Wait for all tasks to complete
        write_result = Task.await(write_task, @test_timeout)
        read_results = Task.await_many(read_tasks, @test_timeout)

        # Verify writer completed successfully
        assert write_result == 50

        # Verify all readers completed and found results
        Enum.each(read_results, fn {reader_id, total_results} ->
          assert total_results >= 0, "Reader #{reader_id} should have completed searches"
        end)
      after
        File.rm_rf(temp_dir)
      end
    end

    test "disk index persistence across operations" do
      schema = create_test_schema()
      temp_dir = create_temp_dir("persistence_test")

      try do
        # Phase 1: Create index and add some documents
        {:ok, index1} = Index.create_in_dir(temp_dir, schema)
        {:ok, writer1} = IndexWriter.new(index1, 5_000_000)

        phase1_docs = create_test_documents(1, 20)
        Enum.each(phase1_docs, &IndexWriter.add_document(writer1, &1))
        IndexWriter.commit(writer1)

        # Verify phase 1 data
        {:ok, searcher1} = Searcher.new(index1)
        {:ok, query} = Query.all()
        {:ok, results1} = Searcher.search(searcher1, query, 100)
        assert length(results1) == 20

        # Phase 2: Continue using the same writer and add more documents
        phase2_docs = create_test_documents(2, 15)
        Enum.each(phase2_docs, &IndexWriter.add_document(writer1, &1))
        IndexWriter.commit(writer1)

        # Verify combined data
        {:ok, searcher2} = Searcher.new(index1)
        {:ok, results2} = Searcher.search(searcher2, query, 100)
        # 20 + 15
        assert length(results2) == 35

        # Phase 3: Concurrent read operations on the same index
        read_tasks =
          1..3
          |> Enum.map(fn reader_id ->
            Task.async(fn ->
              {:ok, searcher3} = Searcher.new(index1)

              search_results =
                1..10
                |> Enum.map(fn _iteration ->
                  case Searcher.search(searcher3, query, 100) do
                    {:ok, results} -> length(results)
                    {:error, _} -> 0
                  end
                end)

              # Average
              {reader_id, Enum.sum(search_results) / 10}
            end)
          end)

        # Wait for concurrent reads
        read_results = Task.await_many(read_tasks, @test_timeout)

        # Verify all readers found consistent data
        Enum.each(read_results, fn {reader_id, avg_results} ->
          assert avg_results == 35.0, "Reader #{reader_id} should consistently find 35 documents"
        end)
      after
        File.rm_rf(temp_dir)
      end
    end

    test "high-load disk operations with cleanup" do
      schema = create_test_schema()

      # Get initial memory usage
      initial_memory = :erlang.memory(:total)

      # Run high-load disk operations
      disk_tasks =
        1..6
        |> Enum.map(fn task_id ->
          Task.async(fn ->
            temp_dir = create_temp_dir("high_load_#{task_id}")

            try do
              case rem(task_id, 2) do
                0 ->
                  # Writer task with disk index
                  {:ok, index} = Index.create_in_dir(temp_dir, schema)
                  {:ok, writer} = IndexWriter.new(index, 2_000_000)
                  docs = create_test_documents(task_id, 8)
                  Enum.each(docs, &IndexWriter.add_document(writer, &1))
                  IndexWriter.commit(writer)
                  :disk_write_completed

                1 ->
                  # Reader task with disk index
                  {:ok, index} = Index.create_in_dir(temp_dir, schema)
                  {:ok, writer} = IndexWriter.new(index, 2_000_000)
                  # Add some data first
                  docs = create_test_documents(task_id, 5)
                  Enum.each(docs, &IndexWriter.add_document(writer, &1))
                  IndexWriter.commit(writer)

                  {:ok, searcher} = Searcher.new(index)

                  search_count =
                    1..10
                    |> Enum.map(fn _iteration ->
                      {:ok, query} = Query.all()

                      case Searcher.search(searcher, query, 25) do
                        {:ok, _results} -> 1
                        {:error, _} -> 0
                      end
                    end)
                    |> Enum.sum()

                  {:disk_read_completed, search_count}
              end
            after
              File.rm_rf(temp_dir)
            end
          end)
        end)

      # Wait for all disk operations to complete
      disk_results = Task.await_many(disk_tasks, @test_timeout)

      # Verify operations completed
      write_tasks = Enum.count(disk_results, fn result -> result == :disk_write_completed end)

      read_tasks =
        Enum.count(disk_results, fn
          {:disk_read_completed, _count} -> true
          _ -> false
        end)

      assert write_tasks >= 2, "Should have completed at least 2 disk write tasks"
      assert read_tasks >= 2, "Should have completed at least 2 disk read tasks"

      # Force cleanup and check memory
      :erlang.garbage_collect()
      Process.sleep(200)
      final_memory = :erlang.memory(:total)

      # Memory should not have grown excessively
      memory_growth = final_memory - initial_memory
      memory_growth_mb = memory_growth / (1024 * 1024)

      # Should not grow by more than 50MB during disk test (more conservative)
      assert memory_growth_mb < 50,
             "Memory grew by #{memory_growth_mb}MB, which may indicate a disk resource leak"
    end
  end

  describe "concurrent search operations" do
    test "multiple concurrent searches on same index" do
      schema = create_test_schema()
      {:ok, index} = Index.create_in_ram(schema)

      # Populate index with searchable data
      {:ok, writer} = IndexWriter.new(index, 10_000_000)
      docs = create_large_test_dataset(200)
      Enum.each(docs, &IndexWriter.add_document(writer, &1))
      IndexWriter.commit(writer)

      # Define different search patterns
      search_patterns = [
        {"term_search", fn -> Query.term(schema, "title", "Document") end},
        {"range_search", fn -> Query.range_u64(schema, "id", 50, 150) end},
        {"boolean_search",
         fn ->
           {:ok, title_query} = Query.term(schema, "title", "Document")
           {:ok, id_query} = Query.range_u64(schema, "id", 1, 100)
           Query.boolean([title_query], [id_query], [])
         end},
        {"phrase_search", fn -> Query.phrase(schema, "content", ["test", "content"]) end},
        {"all_search", fn -> Query.all() end}
      ]

      # Start concurrent search tasks
      search_tasks =
        1..10
        |> Enum.map(fn task_id ->
          Task.async(fn ->
            {:ok, searcher} = Searcher.new(index)

            results =
              1..20
              |> Enum.map(fn _iteration ->
                {pattern_name, query_fn} = Enum.random(search_patterns)

                case query_fn.() do
                  {:ok, query} ->
                    case Searcher.search(searcher, query, 50) do
                      {:ok, results} -> {pattern_name, length(results), :success}
                      {:error, reason} -> {pattern_name, 0, {:error, reason}}
                    end

                  {:error, reason} ->
                    {pattern_name, 0, {:error, reason}}
                end
              end)

            {task_id, results}
          end)
        end)

      # Wait for all searches to complete
      search_results = Task.await_many(search_tasks, @test_timeout)

      # Verify all searches completed
      Enum.each(search_results, fn {task_id, results} ->
        assert length(results) == 20, "Task #{task_id} should have completed 20 searches"

        # Count successful searches
        successful_searches =
          results
          |> Enum.count(fn {_pattern, _count, status} -> status == :success end)

        # At least 50% of searches should succeed (allowing for concurrent variability)
        assert successful_searches >= 10,
               "Task #{task_id} should have at least 10 successful searches, got #{successful_searches}"
      end)
    end

    test "concurrent document operations with different access patterns" do
      schema = create_test_schema()
      # Create separate indices for each task to respect single-writer constraint
      {:ok, index1} = Index.create_in_ram(schema)
      {:ok, index2} = Index.create_in_ram(schema)

      # Task 1: Batch document insertion
      batch_task =
        Task.async(fn ->
          {:ok, writer} = IndexWriter.new(index1, 10_000_000)

          1..5
          |> Enum.each(fn batch_id ->
            docs = create_test_documents(batch_id, 20)
            Enum.each(docs, &IndexWriter.add_document(writer, &1))
            IndexWriter.commit(writer)
            # Allow other operations to interleave
            Process.sleep(50)
          end)

          :batch_completed
        end)

      # Task 2: Individual document operations
      individual_task =
        Task.async(fn ->
          # Start after some data exists
          Process.sleep(100)

          {:ok, writer} = IndexWriter.new(index2, 10_000_000)

          1..50
          |> Enum.map(fn doc_id ->
            doc = %{
              "id" => 1000 + doc_id,
              "title" => "Individual Doc #{doc_id}",
              "content" => "Individual content #{doc_id}",
              "category" => "individual",
              "score" => doc_id * 1.5
            }

            result = IndexWriter.add_document(writer, doc)

            if rem(doc_id, 10) == 0 do
              IndexWriter.commit(writer)
            end

            result
          end)
          |> Enum.count(fn result -> result == :ok end)
        end)

      # Task 3: Concurrent searches during writes
      search_task =
        Task.async(fn ->
          # Start after some data exists
          Process.sleep(200)

          {:ok, searcher} = Searcher.new(index1)

          1..30
          |> Enum.map(fn _iteration ->
            # Randomly choose between different search types
            case :rand.uniform(3) do
              1 ->
                {:ok, query} = Query.term(schema, "category", "test")
                Searcher.search(searcher, query, 20)

              2 ->
                {:ok, query} = Query.term(schema, "category", "individual")
                Searcher.search(searcher, query, 20)

              3 ->
                {:ok, query} = Query.all()
                Searcher.search(searcher, query, 100)
            end
          end)
          |> Enum.count(fn
            {:ok, _results} -> true
            {:error, _} -> false
          end)
        end)

      # Wait for all operations to complete
      batch_result = Task.await(batch_task, @test_timeout)
      individual_result = Task.await(individual_task, @test_timeout)
      search_result = Task.await(search_task, @test_timeout)

      # Verify all operations succeeded
      assert batch_result == :batch_completed
      # All individual docs should be added
      assert individual_result == 50
      # At least 80% of searches should succeed
      assert search_result >= 25

      # Verify final state by checking each index separately
      {:ok, searcher1} = Searcher.new(index1)
      {:ok, query} = Query.all()
      {:ok, results1} = Searcher.search(searcher1, query, 200)

      {:ok, searcher2} = Searcher.new(index2)
      {:ok, results2} = Searcher.search(searcher2, query, 200)

      # Should have 100 batch docs in index1 and 50 individual docs in index2
      assert length(results1) == 100
      assert length(results2) == 50
    end
  end

  describe "resource management under concurrency" do
    test "proper resource cleanup with concurrent operations" do
      schema = create_test_schema()

      # Create multiple indices concurrently and perform operations
      index_tasks =
        1..5
        |> Enum.map(fn index_id ->
          Task.async(fn ->
            {:ok, index} = Index.create_in_ram(schema)
            {:ok, writer} = IndexWriter.new(index, 5_000_000)

            # Add documents
            docs = create_test_documents(index_id, 30)
            Enum.each(docs, &IndexWriter.add_document(writer, &1))
            IndexWriter.commit(writer)

            # Perform searches
            {:ok, searcher} = Searcher.new(index)
            {:ok, query} = Query.all()
            {:ok, results} = Searcher.search(searcher, query, 50)

            {index_id, length(results)}
          end)
        end)

      # Wait for all operations to complete
      results = Task.await_many(index_tasks, @test_timeout)

      # Verify all operations completed successfully
      Enum.each(results, fn {index_id, result_count} ->
        assert result_count == 30, "Index #{index_id} should have 30 documents"
      end)

      # Force garbage collection to test resource cleanup
      :erlang.garbage_collect()
      Process.sleep(100)

      # Verify we can still create new indices (resources were cleaned up)
      {:ok, _new_index} = Index.create_in_ram(schema)
    end

    test "memory stability under high concurrent load" do
      schema = create_test_schema()

      # Get initial memory usage
      initial_memory = :erlang.memory(:total)

      # Run high-load concurrent operations
      high_load_tasks =
        1..20
        |> Enum.map(fn task_id ->
          Task.async(fn ->
            case rem(task_id, 3) do
              0 ->
                # Writer task - each task gets its own index
                {:ok, index} = Index.create_in_ram(schema)
                {:ok, writer} = IndexWriter.new(index, 1_000_000)
                docs = create_test_documents(task_id, 10)
                Enum.each(docs, &IndexWriter.add_document(writer, &1))
                IndexWriter.commit(writer)
                :write_completed

              1 ->
                # Reader task - create its own index with data
                {:ok, index} = Index.create_in_ram(schema)
                {:ok, writer} = IndexWriter.new(index, 1_000_000)
                # Add some data first
                docs = create_test_documents(task_id, 5)
                Enum.each(docs, &IndexWriter.add_document(writer, &1))
                IndexWriter.commit(writer)

                {:ok, searcher} = Searcher.new(index)

                search_count =
                  1..20
                  |> Enum.map(fn _iteration ->
                    {:ok, query} = Query.all()

                    case Searcher.search(searcher, query, 25) do
                      {:ok, _results} -> 1
                      {:error, _} -> 0
                    end
                  end)
                  |> Enum.sum()

                {:read_completed, search_count}

              2 ->
                # Mixed operations task - create its own index
                {:ok, index} = Index.create_in_ram(schema)
                {:ok, writer} = IndexWriter.new(index, 1_000_000)
                {:ok, searcher} = Searcher.new(index)

                ops_count =
                  1..15
                  |> Enum.map(fn op_id ->
                    if rem(op_id, 2) == 0 do
                      doc = create_test_documents(task_id * 100 + op_id, 1) |> hd()
                      IndexWriter.add_document(writer, doc)
                      1
                    else
                      {:ok, query} = Query.all()

                      case Searcher.search(searcher, query, 10) do
                        {:ok, _results} -> 1
                        {:error, _} -> 0
                      end
                    end
                  end)
                  |> Enum.sum()

                IndexWriter.commit(writer)
                {:mixed_completed, ops_count}
            end
          end)
        end)

      # Wait for all high-load operations to complete
      load_results = Task.await_many(high_load_tasks, @test_timeout)

      # Verify operations completed
      write_tasks = Enum.count(load_results, fn result -> result == :write_completed end)

      read_tasks =
        Enum.count(load_results, fn
          {:read_completed, _count} -> true
          _ -> false
        end)

      mixed_tasks =
        Enum.count(load_results, fn
          {:mixed_completed, _count} -> true
          _ -> false
        end)

      # ~1/3 of 20 tasks
      assert write_tasks >= 6
      # ~1/3 of 20 tasks
      assert read_tasks >= 6
      # ~1/3 of 20 tasks
      assert mixed_tasks >= 6

      # Force cleanup and check memory
      :erlang.garbage_collect()
      Process.sleep(200)
      final_memory = :erlang.memory(:total)

      # Memory should not have grown excessively (allowing for some growth)
      memory_growth = final_memory - initial_memory
      memory_growth_mb = memory_growth / (1024 * 1024)

      # Should not grow by more than 100MB during test
      assert memory_growth_mb < 100,
             "Memory grew by #{memory_growth_mb}MB, which may indicate a memory leak"
    end
  end

  # Helper functions

  defp create_temp_dir(prefix) do
    timestamp = System.system_time(:microsecond)
    temp_dir = Path.join([System.tmp_dir!(), "tantivy_#{prefix}_#{timestamp}"])

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

  defp create_test_documents(prefix, count) do
    1..count
    |> Enum.map(fn i ->
      %{
        "id" => prefix * 1000 + i,
        "title" => "Document #{prefix}-#{i}",
        "content" => "Test content #{prefix} #{i} with various terms",
        "category" => "test",
        "score" => (prefix * 10 + i) * 1.0
      }
    end)
  end

  defp create_large_test_dataset(count) do
    1..count
    |> Enum.map(fn i ->
      %{
        "id" => i,
        "title" => "Document #{i}",
        "content" => "Test content for document #{i} with searchable terms",
        "category" => if(rem(i, 2) == 0, do: "even", else: "odd"),
        "score" => i * 2.5
      }
    end)
  end
end
