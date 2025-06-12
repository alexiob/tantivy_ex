defmodule TantivyExQueryTest do
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

    # Add test documents
    docs = [
      %{
        "title" => "Term Test Document",
        "content" => "Content for term test",
        "id" => 1001,
        "score" => 85.0,
        "published" => true,
        "created_at" => "2023-01-01T00:00:00Z"
      },
      %{
        "title" => "Another Test Document",
        "content" => "More test content",
        "id" => 1002,
        "score" => 90.0,
        "published" => false,
        "created_at" => "2023-01-02T00:00:00Z"
      }
    ]

    {:ok, _} = Document.add_batch(writer, docs, schema)
    :ok = IndexWriter.commit(writer)

    {:ok, searcher} = Searcher.new(index)

    %{schema: schema, index: index, writer: writer, searcher: searcher}
  end

  test "term query with text field works correctly", %{schema: schema, searcher: searcher} do
    # Search for a text field term
    {:ok, query} = Query.term(schema, "title", "Term Test Document")
    {:ok, results} = Searcher.search(searcher, query, 10)

    assert length(results) == 1
    doc = hd(results)
    assert doc["title"] == "Term Test Document"
  end

  test "term query with numeric field works correctly", %{schema: schema, searcher: searcher} do
    # Search for a numeric field by its string representation
    {:ok, query} = Query.term(schema, "id", "1001")
    {:ok, results} = Searcher.search(searcher, query, 10)

    assert length(results) == 1
    doc = hd(results)
    assert doc["id"] == 1001
  end

  test "term query with boolean field works correctly", %{schema: schema, searcher: searcher} do
    # Search for a boolean field by its string representation
    {:ok, query} = Query.term(schema, "published", "true")
    {:ok, results} = Searcher.search(searcher, query, 10)

    assert length(results) == 1
    doc = hd(results)
    assert doc["published"] == true
  end

  test "all query works correctly", %{searcher: searcher} do
    # Get all documents
    {:ok, query} = Query.all()
    {:ok, results} = Searcher.search(searcher, query, 10)

    assert length(results) == 2
  end
end
