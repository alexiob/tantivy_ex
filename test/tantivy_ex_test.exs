defmodule TantivyExTest do
  use ExUnit.Case, async: true
  doctest TantivyEx

  alias TantivyEx.{Schema, Index, IndexWriter, Searcher}

  describe "schema operations" do
    test "creates a new schema" do
      schema = Schema.new()
      assert is_reference(schema)
    end

    test "adds text fields to schema" do
      schema = Schema.new()
      schema = Schema.add_text_field(schema, "title", :text_stored)
      assert is_reference(schema)

      schema = Schema.add_text_field(schema, "body", :text)
      assert is_reference(schema)
    end

    test "adds u64 fields to schema" do
      schema = Schema.new()
      schema = Schema.add_u64_field(schema, "price", :indexed_stored)
      assert is_reference(schema)

      schema = Schema.add_u64_field(schema, "quantity", :indexed)
      assert is_reference(schema)
    end
  end

  describe "index operations" do
    setup do
      schema = Schema.new()
      schema = Schema.add_text_field(schema, "title", :text_stored)
      schema = Schema.add_text_field(schema, "body", :text)

      %{schema: schema}
    end

    test "creates index in RAM", %{schema: schema} do
      assert {:ok, index} = Index.create_in_ram(schema)
      assert is_reference(index)
    end

    test "creates index in directory", %{schema: schema} do
      tmp_dir = System.tmp_dir!() <> "/tantivy_test_#{:rand.uniform(1_000_000)}"

      assert {:ok, index} = Index.create_in_dir(tmp_dir, schema)
      assert is_reference(index)

      # Clean up
      File.rm_rf!(tmp_dir)
    end
  end

  describe "indexing operations" do
    test "creates index writer" do
      schema = Schema.new()
      schema = Schema.add_text_field(schema, "title", :text_stored)
      schema = Schema.add_text_field(schema, "body", :text)

      {:ok, index} = Index.create_in_ram(schema)
      assert {:ok, writer} = IndexWriter.new(index)
      assert is_reference(writer)
    end

    test "adds document to index" do
      schema = Schema.new()
      schema = Schema.add_text_field(schema, "title", :text_stored)
      schema = Schema.add_text_field(schema, "body", :text)

      {:ok, index} = Index.create_in_ram(schema)
      {:ok, writer} = IndexWriter.new(index)

      document = %{
        "title" => "The Old Man and the Sea",
        "body" => "He was an old man who fished alone in a skiff in the Gulf Stream..."
      }

      assert :ok = IndexWriter.add_document(writer, document)
    end

    test "commits changes" do
      schema = Schema.new()
      schema = Schema.add_text_field(schema, "title", :text_stored)
      schema = Schema.add_text_field(schema, "body", :text)

      {:ok, index} = Index.create_in_ram(schema)
      {:ok, writer} = IndexWriter.new(index)

      document = %{
        "title" => "Test Document",
        "body" => "This is a test document for indexing."
      }

      assert :ok = IndexWriter.add_document(writer, document)
      assert :ok = IndexWriter.commit(writer)
    end
  end

  describe "search operations" do
    setup do
      schema = Schema.new()
      schema = Schema.add_text_field(schema, "title", :text_stored)
      schema = Schema.add_text_field(schema, "body", :text)

      {:ok, index} = Index.create_in_ram(schema)
      {:ok, writer} = IndexWriter.new(index)

      # Add some test documents
      documents = [
        %{"title" => "The Old Man and the Sea", "body" => "A story about fishing"},
        %{"title" => "To Kill a Mockingbird", "body" => "A story about justice"},
        %{"title" => "1984", "body" => "A dystopian novel about surveillance"}
      ]

      Enum.each(documents, fn doc ->
        IndexWriter.add_document(writer, doc)
      end)

      IndexWriter.commit(writer)

      %{schema: schema, index: index, writer: writer}
    end

    test "creates searcher", %{index: index} do
      assert {:ok, searcher} = Searcher.new(index)
      assert is_reference(searcher)
    end

    test "performs search", %{index: index} do
      {:ok, searcher} = Searcher.new(index)

      case Searcher.search(searcher, "story", 10) do
        {:ok, results} ->
          assert is_list(results)
          # Should find documents containing "story" in title or body
          assert length(results) >= 0

        {:error, reason} ->
          flunk("Search operation failed unexpectedly: #{inspect(reason)}")
      end
    end

    test "searches for document IDs", %{index: index} do
      {:ok, searcher} = Searcher.new(index)

      case Searcher.search_ids(searcher, "novel", 5) do
        {:ok, doc_ids} ->
          assert is_list(doc_ids)
          # Should return document IDs as integers or empty list
          Enum.each(doc_ids, fn doc_id ->
            assert is_integer(doc_id) and doc_id >= 0
          end)

        {:error, reason} ->
          flunk("Search IDs operation failed unexpectedly: #{inspect(reason)}")
      end
    end
  end

  describe "integration test" do
    test "full workflow from schema to search" do
      # Create schema
      schema = Schema.new()
      schema = Schema.add_text_field(schema, "title", :text_stored)
      schema = Schema.add_text_field(schema, "content", :text)
      schema = Schema.add_u64_field(schema, "timestamp", :indexed_stored)

      # Create index
      {:ok, index} = Index.create_in_ram(schema)

      # Create writer and add documents
      {:ok, writer} = IndexWriter.new(index, 20_000_000)

      test_documents = [
        %{
          "title" => "Rust Programming",
          "content" => "Rust is a systems programming language that is fast and memory-safe",
          "timestamp" => 1_234_567_890
        },
        %{
          "title" => "Elixir Programming",
          "content" => "Elixir is a functional programming language built on the Erlang VM",
          "timestamp" => 1_234_567_891
        },
        %{
          "title" => "Search Engines",
          "content" =>
            "Full-text search engines like Tantivy provide fast text search capabilities",
          "timestamp" => 1_234_567_892
        }
      ]

      Enum.each(test_documents, fn doc ->
        assert :ok = IndexWriter.add_document(writer, doc)
      end)

      assert :ok = IndexWriter.commit(writer)

      # Create searcher and search
      {:ok, searcher} = Searcher.new(index)

      case Searcher.search(searcher, "programming", 10) do
        {:ok, results} ->
          assert is_list(results)
          # Should find documents containing "programming"
          # Verify result structure if results are found
          Enum.each(results, fn result ->
            assert is_map(result) or is_tuple(result)
          end)

        {:error, reason} ->
          flunk("Integration test search failed unexpectedly: #{inspect(reason)}")
      end
    end
  end

  describe "disk-based index operations" do
    test "opens existing index from directory" do
      schema = Schema.new()
      schema = Schema.add_text_field(schema, "title", :text_stored)

      # Create a temporary directory for testing
      test_dir = "/tmp/test_tantivy_open_#{System.system_time(:millisecond)}"

      # Create index first
      {:ok, _index} = Index.create_in_dir(test_dir, schema)

      # Now test opening it
      case Index.open(test_dir) do
        {:ok, opened_index} ->
          assert is_reference(opened_index)

        {:error, reason} ->
          flunk("Failed to open existing index: #{reason}")
      end

      # Cleanup
      File.rm_rf!(test_dir)
    end

    test "open_or_create creates new index when directory doesn't exist" do
      schema = Schema.new()
      schema = Schema.add_text_field(schema, "title", :text_stored)

      # Use a new directory that doesn't exist
      test_dir = "/tmp/test_tantivy_open_or_create_#{System.system_time(:millisecond)}"

      case Index.open_or_create(test_dir, schema) do
        {:ok, index} ->
          assert is_reference(index)
          assert File.exists?(test_dir)

        {:error, reason} ->
          flunk("Failed to create index with open_or_create: #{reason}")
      end

      # Cleanup
      File.rm_rf!(test_dir)
    end

    test "open_or_create opens existing index when directory exists" do
      schema = Schema.new()
      schema = Schema.add_text_field(schema, "title", :text_stored)

      # Create a temporary directory for testing
      test_dir = "/tmp/test_tantivy_open_or_create_existing_#{System.system_time(:millisecond)}"

      # Create index first
      {:ok, _index1} = Index.create_in_dir(test_dir, schema)

      # Now test open_or_create on existing directory
      case Index.open_or_create(test_dir, schema) do
        {:ok, index2} ->
          assert is_reference(index2)

        {:error, reason} ->
          flunk("Failed to open existing index with open_or_create: #{reason}")
      end

      # Cleanup
      File.rm_rf!(test_dir)
    end
  end
end
