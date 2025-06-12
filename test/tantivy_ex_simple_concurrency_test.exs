defmodule TantivyEx.SimpleConcurrencyTest do
  @moduledoc """
  Basic concurrency tests for TantivyEx.

  Note: Tantivy enforces a single-writer constraint per index, so tests
  with multiple writers use separate indices or sequential access patterns.
  """

  use ExUnit.Case, async: true

  alias TantivyEx.{Schema, Index, IndexWriter, Searcher, Query}

  test "concurrent writes to separate indices" do
    schema = Schema.new()
    schema = Schema.add_u64_field(schema, "id", :indexed_stored)
    schema = Schema.add_text_field(schema, "title", :text_stored)

    # Start 3 concurrent writers with separate indices
    tasks =
      1..3
      |> Enum.map(fn writer_id ->
        Task.async(fn ->
          # Each writer gets its own index
          {:ok, index} = Index.create_in_ram(schema)
          {:ok, writer} = IndexWriter.new(index, 1_000_000)

          # Each writer adds 5 documents
          1..5
          |> Enum.each(fn doc_id ->
            doc = %{
              "id" => writer_id * 10 + doc_id,
              "title" => "Document #{writer_id}-#{doc_id}"
            }

            IndexWriter.add_document(writer, doc)
          end)

          IndexWriter.commit(writer)

          # Verify documents are searchable in this index
          {:ok, searcher} = Searcher.new(index)
          {:ok, query} = Query.all()
          {:ok, search_results} = Searcher.search(searcher, query, 10)

          {writer_id, length(search_results)}
        end)
      end)

    # Wait for all writers to complete
    results = Task.await_many(tasks, 10_000)

    # Verify all writers completed successfully
    assert length(results) == 3

    # Each writer should have indexed 5 documents in their separate index
    Enum.each(results, fn {writer_id, doc_count} ->
      assert doc_count == 5, "Writer #{writer_id} should have indexed 5 documents"
    end)
  end

  test "single writer with concurrent reads" do
    schema = Schema.new()
    schema = Schema.add_u64_field(schema, "id", :indexed_stored)
    schema = Schema.add_text_field(schema, "content", :text)

    {:ok, index} = Index.create_in_ram(schema)
    {:ok, writer} = IndexWriter.new(index, 1_000_000)

    # Pre-populate with some initial data
    1..5
    |> Enum.each(fn i ->
      doc = %{"id" => i, "content" => "initial content #{i}"}
      IndexWriter.add_document(writer, doc)
    end)

    IndexWriter.commit(writer)

    # Start concurrent reader tasks (readers can be concurrent)
    read_tasks =
      1..3
      |> Enum.map(fn reader_id ->
        Task.async(fn ->
          search_counts =
            1..8
            |> Enum.map(fn _iteration ->
              # Pause between searches to allow writes to happen
              Process.sleep(25)

              {:ok, searcher} = Searcher.new(index)
              {:ok, query} = Query.all()

              case Searcher.search(searcher, query, 25) do
                {:ok, results} ->
                  count = length(results)

                  count

                {:error, _} ->
                  0
              end
            end)

          {reader_id, search_counts}
        end)
      end)

    # Perform additional writes while readers are active (single writer adding more docs)
    additional_write_task =
      Task.async(fn ->
        # Wait a bit to let readers start
        Process.sleep(50)

        6..15
        |> Enum.each(fn i ->
          doc = %{"id" => i, "content" => "additional content #{i}"}
          IndexWriter.add_document(writer, doc)

          # Commit periodically to make documents searchable
          if rem(i, 3) == 0 do
            IndexWriter.commit(writer)
          end

          # Allow readers to see changes
          Process.sleep(30)
        end)

        # Final commit
        IndexWriter.commit(writer)
        :write_completed
      end)

    # Wait for completion
    write_result = Task.await(additional_write_task, 10_000)
    read_results = Task.await_many(read_tasks, 10_000)

    # Verify operations completed
    assert write_result == :write_completed

    # Verify readers found results and saw the index grow
    Enum.each(read_results, fn {reader_id, search_counts} ->
      total_searches = length(search_counts)
      assert total_searches > 0, "Reader #{reader_id} should have performed searches"

      # At least some searches should have found documents
      successful_searches = Enum.count(search_counts, &(&1 > 0))
      assert successful_searches > 0, "Reader #{reader_id} should have found some results"
    end)

    # Verify final state - should have 15 documents total
    {:ok, searcher} = Searcher.new(index)
    {:ok, query} = Query.all()
    {:ok, final_results} = Searcher.search(searcher, query, 25)
    assert length(final_results) == 15, "Final index should contain 15 documents"
  end

  test "concurrent writes to separate disk indices" do
    schema = Schema.new()
    schema = Schema.add_u64_field(schema, "id", :indexed_stored)
    schema = Schema.add_text_field(schema, "title", :text_stored)

    # Start 3 concurrent writers with separate disk indices
    tasks =
      1..3
      |> Enum.map(fn writer_id ->
        Task.async(fn ->
          # Create unique directory for each writer
          temp_dir = create_temp_dir("simple_disk_#{writer_id}")

          try do
            {:ok, index} = Index.create_in_dir(temp_dir, schema)
            {:ok, writer} = IndexWriter.new(index, 1_000_000)

            # Add some documents
            1..5
            |> Enum.each(fn doc_id ->
              doc = %{
                "id" => writer_id * 100 + doc_id,
                "title" => "Writer #{writer_id} Document #{doc_id}"
              }

              IndexWriter.add_document(writer, doc)
            end)

            # Commit the documents
            IndexWriter.commit(writer)

            # Verify by searching
            {:ok, searcher} = Searcher.new(index)
            {:ok, query} = Query.all()
            {:ok, results} = Searcher.search(searcher, query, 10)

            {writer_id, length(results)}
          after
            File.rm_rf(temp_dir)
          end
        end)
      end)

    # Wait for all writers to complete
    results = Task.await_many(tasks, 10_000)

    # Verify all writers succeeded
    Enum.each(results, fn {writer_id, doc_count} ->
      assert doc_count == 5, "Writer #{writer_id} should have indexed 5 documents"
    end)
  end

  test "single writer with concurrent reads on disk index" do
    schema = Schema.new()
    schema = Schema.add_u64_field(schema, "id", :indexed_stored)
    schema = Schema.add_text_field(schema, "title", :text_stored)
    schema = Schema.add_text_field(schema, "content", :text)

    temp_dir = create_temp_dir("single_writer_disk")

    try do
      {:ok, index} = Index.create_in_dir(temp_dir, schema)
      {:ok, writer} = IndexWriter.new(index, 2_000_000)

      # Start writer task that adds documents progressively
      writer_task =
        Task.async(fn ->
          1..20
          |> Enum.each(fn doc_id ->
            doc = %{
              "id" => doc_id,
              "title" => "Document #{doc_id}",
              "content" => "This is content_#{rem(doc_id, 5)} for document #{doc_id}"
            }

            IndexWriter.add_document(writer, doc)

            # Commit every few documents
            if rem(doc_id, 5) == 0 do
              IndexWriter.commit(writer)
              # Allow readers to catch up
              Process.sleep(50)
            end
          end)

          # Final commit
          IndexWriter.commit(writer)
          :completed
        end)

      # Start concurrent readers
      reader_tasks =
        1..3
        |> Enum.map(fn reader_id ->
          Task.async(fn ->
            {:ok, searcher} = Searcher.new(index)

            search_results =
              1..8
              |> Enum.map(fn iteration ->
                # Search for documents
                {:ok, query} = Query.all()

                case Searcher.search(searcher, query, 50) do
                  {:ok, results} ->
                    doc_count = length(results)

                    # Give writer time to add more docs
                    Process.sleep(100)
                    {iteration, doc_count, :success}

                  {:error, reason} ->
                    {iteration, 0, {:error, reason}}
                end
              end)

            _successful_count =
              Enum.count(search_results, fn {_, _, status} -> status == :success end)

            {reader_id, search_results}
          end)
        end)

      # Wait for writer and readers to complete
      writer_result = Task.await(writer_task, 10_000)
      reader_results = Task.await_many(reader_tasks, 10_000)

      # Verify writer completed successfully
      assert writer_result == :completed

      # Verify readers performed searches successfully
      Enum.each(reader_results, fn {reader_id, search_results} ->
        assert length(search_results) == 8, "Reader #{reader_id} should have performed 8 searches"

        successful_searches =
          Enum.count(search_results, fn {_, _, status} -> status == :success end)

        assert successful_searches >= 6,
               "Reader #{reader_id} should have at least 6 successful searches"
      end)
    after
      File.rm_rf(temp_dir)
    end
  end

  # Helper functions

  defp create_temp_dir(prefix) do
    timestamp = System.system_time(:microsecond)
    temp_dir = Path.join([System.tmp_dir!(), "tantivy_simple_#{prefix}_#{timestamp}"])

    # Ensure directory is clean
    if File.exists?(temp_dir) do
      File.rm_rf!(temp_dir)
    end

    File.mkdir_p!(temp_dir)

    temp_dir
  end
end
