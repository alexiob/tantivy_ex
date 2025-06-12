defmodule TantivyExDocumentBatchTest do
  use ExUnit.Case, async: true
  alias TantivyEx.{Schema, Index, IndexWriter, Document, Query, Searcher}

  setup do
    # Create a schema with various field types
    schema =
      Schema.new()
      |> Schema.add_text_field("title", :text_stored)
      |> Schema.add_text_field("content", :text)
      |> Schema.add_u64_field("id", :indexed_stored)
      |> Schema.add_f64_field("score", :fast_stored)
      |> Schema.add_bool_field("published", :indexed_stored)
      |> Schema.add_date_field("created_at", :indexed_stored)

    # Create an in-memory index
    {:ok, index} = Index.create_in_ram(schema)
    {:ok, writer} = IndexWriter.new(index, 50_000_000)

    %{schema: schema, index: index, writer: writer}
  end

  test "add_batch with numeric IDs - search by title", %{
    writer: writer,
    schema: schema,
    index: index
  } do
    # Create documents with numeric IDs
    docs = [
      %{
        "title" => "Document One",
        "content" => "Content 1",
        "id" => 1,
        "score" => 85.0,
        "published" => true,
        "created_at" => "2023-01-01T00:00:00Z"
      },
      %{
        "title" => "Document Two",
        "content" => "Content 2",
        "id" => 2,
        "score" => 92.5,
        "published" => false,
        "created_at" => "2023-01-02T00:00:00Z"
      }
    ]

    # Add documents
    {:ok, results} = Document.add_batch(writer, docs, schema)
    assert length(results) == 2

    # Commit changes
    :ok = IndexWriter.commit(writer)

    # Search for documents using title which should work
    {:ok, searcher} = Searcher.new(index)

    # Check that we can find document with title "Document One"
    {:ok, term_query} = Query.term(schema, "title", "Document One")
    {:ok, search_results} = Searcher.search(searcher, term_query, 10)
    assert length(search_results) == 1
    doc = hd(search_results)
    assert doc["title"] == "Document One"

    # Check that we can find all documents
    {:ok, all_query} = Query.all()
    {:ok, all_results} = Searcher.search(searcher, all_query, 10)
    assert length(all_results) == 2
  end
end
