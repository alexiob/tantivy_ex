defmodule TantivyExDocumentOperationsTest do
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

  test "basic document delete by u64 field", %{writer: writer, schema: schema, index: index} do
    # First add a document
    doc = %{
      "title" => "Document to Delete",
      "content" => "This document will be deleted",
      "id" => 300,
      "score" => 85.0,
      "published" => true,
      "created_at" => "2023-01-01T00:00:00Z"
    }

    assert {:ok, _} = Document.add(writer, doc, schema)
    assert :ok = IndexWriter.commit(writer)

    # Verify document exists
    {:ok, searcher} = Searcher.new(index)
    {:ok, query} = Query.term(schema, "id", "300")
    {:ok, before_results} = Searcher.search(searcher, query, 10)
    assert length(before_results) == 1

    # Delete the document
    assert {:ok, :deleted} = Document.delete(writer, "id", "300", schema)
    assert :ok = IndexWriter.commit(writer)

    # Refresh searcher to see changes
    {:ok, searcher} = Searcher.new(index)

    # Verify document was deleted
    {:ok, after_results} = Searcher.search(searcher, query, 10)
    assert length(after_results) == 0
  end

  test "delete document using boolean field term", %{writer: writer, schema: schema, index: index} do
    # Add documents with different boolean values
    docs = [
      %{
        "title" => "Published Document",
        "content" => "This document is published",
        "id" => 401,
        "score" => 85.0,
        "published" => true,
        "created_at" => "2023-01-01T00:00:00Z"
      },
      %{
        "title" => "Unpublished Document",
        "content" => "This document is not published",
        "id" => 402,
        "score" => 90.0,
        "published" => false,
        "created_at" => "2023-01-02T00:00:00Z"
      }
    ]

    assert {:ok, _} = Document.add_batch(writer, docs, schema)
    assert :ok = IndexWriter.commit(writer)

    # Verify initial documents
    {:ok, searcher} = Searcher.new(index)
    {:ok, all_query} = Query.all()
    {:ok, all_results} = Searcher.search(searcher, all_query, 10)
    assert length(all_results) == 2

    # Delete published document (published=true)
    assert {:ok, :deleted} = Document.delete(writer, "published", "true", schema)
    assert :ok = IndexWriter.commit(writer)

    # Verify only unpublished document remains
    {:ok, searcher} = Searcher.new(index)
    {:ok, all_results} = Searcher.search(searcher, all_query, 10)
    assert length(all_results) == 1

    unpublished_doc = hd(all_results)
    assert unpublished_doc["published"] == false
  end

  test "update document by term field", %{writer: writer, schema: schema, index: index} do
    # First add a document
    original_doc = %{
      "title" => "Original Title",
      "content" => "Original content",
      "id" => 100,
      "score" => 85.0,
      "published" => true,
      "created_at" => "2023-01-01T00:00:00Z"
    }

    assert {:ok, _} = Document.add(writer, original_doc, schema)
    assert :ok = IndexWriter.commit(writer)

    # Update the document
    updated_doc = %{
      "title" => "Updated Title",
      "content" => "Updated content",
      # Same ID
      "id" => 100,
      "score" => 95.0,
      "published" => false,
      "created_at" => "2023-02-01T00:00:00Z"
    }

    assert {:ok, :updated} = Document.update(writer, "id", "100", updated_doc, schema)
    assert :ok = IndexWriter.commit(writer)

    # Verify the update by searching
    {:ok, searcher} = Searcher.new(index)
    {:ok, query} = Query.term(schema, "id", "100")
    {:ok, search_results} = Searcher.search(searcher, query, 10)

    assert length(search_results) == 1
    doc = hd(search_results)

    # Verify updated fields
    assert doc["title"] == "Updated Title"
    assert doc["score"] == 95.0
    assert doc["published"] == false
  end
end
