defmodule TantivyExIndexWriterOperationsTest do
  use ExUnit.Case, async: true
  alias TantivyEx.{Schema, Index, IndexWriter, Query, Searcher}

  setup do
    # Create a schema with various field types
    schema =
      Schema.new()
      |> Schema.add_text_field("title", :text_stored)
      |> Schema.add_text_field("content", :text)
      |> Schema.add_text_field("category", :text_stored)
      |> Schema.add_u64_field("id", :indexed_stored)
      |> Schema.add_bool_field("active", :indexed_stored)

    # Create an in-memory index
    {:ok, index} = Index.create_in_ram(schema)
    {:ok, writer} = IndexWriter.new(index, 50_000_000)

    %{schema: schema, index: index, writer: writer}
  end

  test "delete_all_documents should remove all documents from the index", %{
    writer: writer,
    schema: _schema,
    index: index
  } do
    # Add multiple documents
    docs = [
      %{
        "title" => "Document 1",
        "content" => "This is the content of document 1",
        "category" => "test",
        "id" => 1,
        "active" => true
      },
      %{
        "title" => "Document 2",
        "content" => "This is the content of document 2",
        "category" => "test",
        "id" => 2,
        "active" => true
      },
      %{
        "title" => "Document 3",
        "content" => "This is the content of document 3",
        "category" => "example",
        "id" => 3,
        "active" => false
      }
    ]

    # Add each document to the index
    Enum.each(docs, fn doc ->
      :ok = IndexWriter.add_document(writer, doc)
    end)

    # Commit changes
    :ok = IndexWriter.commit(writer)

    # Verify documents were added
    {:ok, searcher} = Searcher.new(index)
    {:ok, query} = Query.all()
    {:ok, results} = Searcher.search(searcher, query, 10)
    assert length(results) == 3

    # Delete all documents
    :ok = IndexWriter.delete_all_documents(writer)
    :ok = IndexWriter.commit(writer)

    # Verify all documents were deleted
    {:ok, searcher} = Searcher.new(index)
    {:ok, results} = Searcher.search(searcher, query, 10)
    assert length(results) == 0
  end

  test "delete_documents should remove documents matching a query", %{
    writer: writer,
    schema: schema,
    index: index
  } do
    # Add multiple documents
    docs = [
      %{
        "title" => "Active Document 1",
        "content" => "This is an active document",
        "category" => "active",
        "id" => 101,
        "active" => true
      },
      %{
        "title" => "Active Document 2",
        "content" => "This is another active document",
        "category" => "active",
        "id" => 102,
        "active" => true
      },
      %{
        "title" => "Inactive Document",
        "content" => "This is an inactive document",
        "category" => "inactive",
        "id" => 103,
        "active" => false
      }
    ]

    # Add each document to the index
    Enum.each(docs, fn doc ->
      :ok = IndexWriter.add_document(writer, doc)
    end)

    # Commit changes
    :ok = IndexWriter.commit(writer)

    # Verify documents were added
    {:ok, searcher} = Searcher.new(index)
    {:ok, all_query} = Query.all()
    {:ok, all_results} = Searcher.search(searcher, all_query, 10)
    assert length(all_results) == 3

    # Create a query to delete active documents
    {:ok, active_query} = Query.term(schema, "active", true)

    # Delete active documents
    :ok = IndexWriter.delete_documents(writer, active_query)
    :ok = IndexWriter.commit(writer)

    # Verify only inactive documents remain
    {:ok, searcher} = Searcher.new(index)
    {:ok, all_results} = Searcher.search(searcher, all_query, 10)
    assert length(all_results) == 1
    assert hd(all_results)["active"] == false
  end

  test "rollback should cancel pending operations", %{
    writer: writer,
    schema: _schema,
    index: index
  } do
    # Add an initial document
    initial_doc = %{
      "title" => "Initial Document",
      "content" => "This is the initial document",
      "category" => "test",
      "id" => 201,
      "active" => true
    }

    :ok = IndexWriter.add_document(writer, initial_doc)
    :ok = IndexWriter.commit(writer)

    # Verify initial document was added
    {:ok, searcher} = Searcher.new(index)
    {:ok, all_query} = Query.all()
    {:ok, initial_results} = Searcher.search(searcher, all_query, 10)
    assert length(initial_results) == 1

    # Add more documents but roll back before committing
    new_docs = [
      %{
        "title" => "New Document 1",
        "content" => "This document will be rolled back",
        "category" => "test",
        "id" => 202,
        "active" => true
      },
      %{
        "title" => "New Document 2",
        "content" => "This document will also be rolled back",
        "category" => "test",
        "id" => 203,
        "active" => true
      }
    ]

    # Add each new document
    Enum.each(new_docs, fn doc ->
      :ok = IndexWriter.add_document(writer, doc)
    end)

    # Roll back instead of committing
    :ok = IndexWriter.rollback(writer)

    # Verify only the initial document remains
    {:ok, searcher} = Searcher.new(index)
    {:ok, final_results} = Searcher.search(searcher, all_query, 10)
    assert length(final_results) == 1
    assert hd(final_results)["id"] == 201
  end
end
