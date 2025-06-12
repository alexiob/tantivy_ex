defmodule TantivyExDocumentOperationsCleanTest do
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

  describe "add_batch function" do
    test "adds batch of documents and validates them", %{
      writer: writer,
      schema: schema,
      index: index
    } do
      docs = [
        %{
          "title" => "Document 1",
          "content" => "Content 1",
          "id" => 1,
          "score" => 85.0,
          "published" => true,
          "created_at" => "2023-01-01T00:00:00Z"
        },
        %{
          "title" => "Document 2",
          "content" => "Content 2",
          "id" => 2,
          "score" => 92.5,
          "published" => false,
          "created_at" => "2023-01-02T00:00:00Z"
        }
      ]

      # Add documents with validation
      assert {:ok, results} = Document.add_batch(writer, docs, schema)
      assert length(results) == 2
      assert :ok = IndexWriter.commit(writer)

      # Check documents were indexed properly
      {:ok, searcher} = Searcher.new(index)
      {:ok, all_query} = Query.all()
      {:ok, all_results} = Searcher.search(searcher, all_query, 10)
      assert length(all_results) == 2
    end

    test "handles validation errors with continue_on_error option", %{
      writer: writer,
      schema: schema
    } do
      docs = [
        %{
          "title" => "Valid Document",
          "content" => "Valid content",
          "id" => 1,
          "score" => 85.0,
          "published" => true,
          "created_at" => "2023-01-01T00:00:00Z"
        },
        %{
          "title" => "Invalid Document",
          # Wrong type
          "id" => "invalid_id",
          "score" => 92.5,
          "published" => false
        }
      ]

      # With continue_on_error: false, should return error
      assert {:error, _errors} =
               Document.add_batch(writer, docs, schema, %{continue_on_error: false})

      # With continue_on_error: true, should process valid documents
      assert {:ok, results} = Document.add_batch(writer, docs, schema, %{continue_on_error: true})
      assert length(results) == 1
    end
  end

  describe "update function" do
    test "updates document by term field and value", %{
      writer: writer,
      schema: schema,
      index: index
    } do
      # Add original document
      doc = %{
        "title" => "Original Title",
        "content" => "Original content",
        "id" => 100,
        "score" => 85.0,
        "published" => true,
        "created_at" => "2023-01-01T00:00:00Z"
      }

      assert {:ok, _} = Document.add(writer, doc, schema)
      assert :ok = IndexWriter.commit(writer)

      # Update the document
      updated_doc = %{
        "title" => "Updated Title",
        "content" => "Updated content",
        "id" => 100,
        "score" => 95.0,
        "published" => false,
        "created_at" => "2023-02-01T00:00:00Z"
      }

      # Use string value for term matching
      assert {:ok, :updated} = Document.update(writer, "id", "100", updated_doc, schema)
      assert :ok = IndexWriter.commit(writer)

      # Verify the update with all_query and check fields
      {:ok, searcher} = Searcher.new(index)
      {:ok, query} = Query.all()
      {:ok, search_results} = Searcher.search(searcher, query, 10)

      assert length(search_results) == 1
      doc = hd(search_results)
      assert doc["title"] == "Updated Title"
      assert doc["score"] == 95.0
      assert doc["published"] == false
    end

    test "updates document by boolean term field", %{writer: writer, schema: schema, index: index} do
      # Add document with published=true
      doc = %{
        "title" => "Published Document",
        "content" => "This is published",
        "id" => 200,
        "score" => 85.0,
        "published" => true,
        "created_at" => "2023-01-01T00:00:00Z"
      }

      assert {:ok, _} = Document.add(writer, doc, schema)
      assert :ok = IndexWriter.commit(writer)

      # Update using published field
      updated_doc = %{
        "title" => "Previously Published Document",
        "content" => "This was published",
        "id" => 200,
        "score" => 90.0,
        "published" => false,
        "created_at" => "2023-02-01T00:00:00Z"
      }

      assert {:ok, :updated} = Document.update(writer, "published", "true", updated_doc, schema)
      assert :ok = IndexWriter.commit(writer)

      # Verify the update
      {:ok, searcher} = Searcher.new(index)
      {:ok, query} = Query.all()
      {:ok, search_results} = Searcher.search(searcher, query, 10)

      assert length(search_results) == 1
      doc = hd(search_results)
      assert doc["title"] == "Previously Published Document"
      assert doc["published"] == false
    end
  end

  describe "delete function" do
    test "deletes document by term field and value", %{
      writer: writer,
      schema: schema,
      index: index
    } do
      # Add document to delete
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
      {:ok, query} = Query.all()
      {:ok, before_results} = Searcher.search(searcher, query, 10)
      assert length(before_results) == 1

      # Delete by string term value
      assert {:ok, :deleted} = Document.delete(writer, "id", "300", schema)
      assert :ok = IndexWriter.commit(writer)

      # Verify document was deleted
      {:ok, searcher} = Searcher.new(index)
      {:ok, after_results} = Searcher.search(searcher, query, 10)
      assert length(after_results) == 0
    end

    test "deletes document by boolean term field", %{writer: writer, schema: schema, index: index} do
      # Add documents with different boolean values
      docs = [
        %{
          "title" => "Published Document",
          "content" => "This is published",
          "id" => 401,
          "score" => 85.0,
          "published" => true,
          "created_at" => "2023-01-01T00:00:00Z"
        },
        %{
          "title" => "Unpublished Document",
          "content" => "This is not published",
          "id" => 402,
          "score" => 90.0,
          "published" => false,
          "created_at" => "2023-01-02T00:00:00Z"
        }
      ]

      assert {:ok, _} = Document.add_batch(writer, docs, schema)
      assert :ok = IndexWriter.commit(writer)

      # Verify both documents exist
      {:ok, searcher} = Searcher.new(index)
      {:ok, query} = Query.all()
      {:ok, before_results} = Searcher.search(searcher, query, 10)
      assert length(before_results) == 2

      # Delete published documents
      assert {:ok, :deleted} = Document.delete(writer, "published", "true", schema)
      assert :ok = IndexWriter.commit(writer)

      # Verify only unpublished document remains
      {:ok, searcher} = Searcher.new(index)
      {:ok, after_results} = Searcher.search(searcher, query, 10)
      assert length(after_results) == 1

      remaining_doc = hd(after_results)
      assert remaining_doc["published"] == false
    end
  end
end
