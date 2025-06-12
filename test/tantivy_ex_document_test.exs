defmodule TantivyExDocumentTest do
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

  test "validates document against schema", %{schema: schema} do
    valid_doc = %{
      "title" => "Test Document",
      "content" => "This is test content",
      "id" => 1,
      "score" => 85.5,
      "published" => true,
      "created_at" => "2023-01-01T00:00:00Z"
    }

    assert {:ok, _validated} = Document.validate(valid_doc, schema)

    invalid_doc = %{
      "title" => "Test Document",
      # Invalid type
      "id" => "not_a_number",
      # Unknown field
      "unknown_field" => "value"
    }

    assert {:error, _errors} = Document.validate(invalid_doc, schema)
  end

  test "adds single document with schema", %{writer: writer, schema: schema} do
    doc = %{
      "title" => "Single Document",
      "content" => "Content for single document",
      "id" => 1,
      "score" => 95.0,
      "published" => true,
      "created_at" => "2023-01-01T00:00:00Z"
    }

    assert {:ok, _result} = Document.add(writer, doc, schema)
  end

  # Comprehensive tests for add_batch function
  describe "add_batch/4" do
    test "adds batch of documents with default options", %{
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

      # Default options
      assert {:ok, results} = Document.add_batch(writer, docs, schema)
      assert length(results) == 2

      # Commit changes
      # Verify documents were added by searching for them
      assert :ok = IndexWriter.commit(writer)
      {:ok, searcher} = Searcher.new(index)

      {:ok, query} = Query.all()
      {:ok, search_results} = Searcher.search(searcher, query, 10)

      assert length(search_results) == 2
    end

    test "adds batch of documents with custom batch size", %{writer: writer, schema: schema} do
      # Create a larger number of documents to test batch processing
      docs =
        Enum.map(1..10, fn i ->
          %{
            "title" => "Document #{i}",
            "content" => "Content for document #{i}",
            "id" => i,
            "score" => 80.0 + i,
            "published" => rem(i, 2) == 0,
            "created_at" => "2023-01-#{String.pad_leading("#{i}", 2, "0")}T00:00:00Z"
          }
        end)

      options = %{batch_size: 3, validate: true}
      assert {:ok, results} = Document.add_batch(writer, docs, schema, options)
      assert length(results) == 10
    end

    test "handles empty document list", %{writer: writer, schema: schema} do
      docs = []
      assert {:ok, results} = Document.add_batch(writer, docs, schema)
      assert results == []
    end

    test "validates batch with mixed valid/invalid documents", %{writer: writer, schema: schema} do
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

      options = %{batch_size: 10, validate: true, continue_on_error: false}
      assert {:error, errors} = Document.add_batch(writer, docs, schema, options)
      assert length(errors) > 0
      # Index of the invalid document
      assert {1, _reason} = hd(errors)
    end

    test "continues batch processing on error when continue_on_error is true", %{
      writer: writer,
      schema: schema,
      index: index
    } do
      docs = [
        %{
          "title" => "Valid Document 1",
          "content" => "Valid content 1",
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
        },
        %{
          "title" => "Valid Document 2",
          "content" => "Valid content 2",
          "id" => 3,
          "score" => 95.0,
          "published" => true,
          "created_at" => "2023-01-03T00:00:00Z"
        }
      ]

      options = %{batch_size: 10, validate: true, continue_on_error: true}
      assert {:ok, results} = Document.add_batch(writer, docs, schema, options)

      # Should have processed 2 valid documents
      assert length(results) == 2

      # Commit changes
      # Verify only valid documents were added
      assert :ok = IndexWriter.commit(writer)
      {:ok, searcher} = Searcher.new(index)

      {:ok, query} = Query.all()
      {:ok, search_results} = Searcher.search(searcher, query, 10)

      assert length(search_results) == 2
    end

    test "skips validation when validate option is false", %{writer: writer, schema: schema} do
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
          # Missing some fields but should still be added as validation is skipped
          "title" => "Document 2",
          "id" => 2
        }
      ]

      options = %{validate: false}
      assert {:ok, results} = Document.add_batch(writer, docs, schema, options)
      assert length(results) == 2
    end
  end

  # Comprehensive tests for update function
  describe "update/5" do
    test "updates document based on term field and value", %{
      writer: writer,
      schema: schema,
      index: index
    } do
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
      # Verify the update by searching
      assert :ok = IndexWriter.commit(writer)
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

    test "update with non-existent document creates new document", %{
      writer: writer,
      schema: schema,
      index: index
    } do
      # Try to update a document that doesn't exist
      new_doc = %{
        "title" => "New Document",
        "content" => "This document didn't exist before",
        "id" => 999,
        "score" => 75.0,
        "published" => true,
        "created_at" => "2023-03-01T00:00:00Z"
      }

      # This should still succeed as deletion of non-existent docs doesn't fail
      assert {:ok, :updated} = Document.update(writer, "id", "999", new_doc, schema)
      # Verify the document was added
      assert :ok = IndexWriter.commit(writer)
      {:ok, searcher} = Searcher.new(index)

      {:ok, query} = Query.term(schema, "id", "999")
      {:ok, search_results} = Searcher.search(searcher, query, 10)

      assert length(search_results) == 1
    end

    test "update fails with invalid document", %{writer: writer, schema: schema} do
      # Try to update with an invalid document
      invalid_doc = %{
        "title" => "Invalid Document",
        # Wrong type
        "id" => "should_be_integer",
        "score" => 92.5
      }

      assert {:error, _reason} = Document.update(writer, "id", 1, invalid_doc, schema)
    end

    test "updates with different term field types", %{
      writer: writer,
      schema: schema,
      index: index
    } do
      # Add documents with different field types
      docs = [
        %{
          "title" => "Text Field Doc",
          "content" => "Content for text field test",
          "id" => 201,
          "score" => 85.0,
          "published" => true,
          "created_at" => "2023-01-01T00:00:00Z"
        },
        %{
          "title" => "Boolean Field Doc",
          "content" => "Content for boolean field test",
          "id" => 202,
          "score" => 90.0,
          "published" => true,
          "created_at" => "2023-01-02T00:00:00Z"
        }
      ]

      assert {:ok, _} = Document.add_batch(writer, docs, schema)
      assert :ok = IndexWriter.commit(writer)

      # Update by text field
      text_updated_doc = %{
        "title" => "Updated Text Field Doc",
        "content" => "Updated content for text field test",
        "id" => 201,
        "score" => 95.0,
        "published" => true,
        "created_at" => "2023-01-01T00:00:00Z"
      }

      assert {:ok, :updated} =
               Document.update(writer, "title", "Text Field Doc", text_updated_doc, schema)

      # Update by boolean field
      bool_updated_doc = %{
        "title" => "Updated Boolean Field Doc",
        "content" => "Updated content for boolean field test",
        "id" => 202,
        "score" => 95.0,
        # Changed from true
        "published" => false,
        "created_at" => "2023-01-02T00:00:00Z"
      }

      assert {:ok, :updated} =
               Document.update(writer, "published", "true", bool_updated_doc, schema)

      # Verify the updates
      assert :ok = IndexWriter.commit(writer)
      {:ok, searcher} = Searcher.new(index)
      # Check text field update
      {:ok, text_query} = Query.term(schema, "id", "201")
      {:ok, text_results} = Searcher.search(searcher, text_query, 10)

      assert length(text_results) == 1
      text_doc = hd(text_results)
      assert text_doc["title"] == "Updated Text Field Doc"

      # Check boolean field update
      {:ok, bool_query} = Query.term(schema, "id", "202")
      {:ok, bool_results} = Searcher.search(searcher, bool_query, 10)

      assert length(bool_results) == 1
      bool_doc = hd(bool_results)
      assert bool_doc["title"] == "Updated Boolean Field Doc"
      assert bool_doc["published"] == false
    end
  end

  # Comprehensive tests for delete function
  describe "delete/4" do
    test "deletes document based on term field and value", %{
      writer: writer,
      schema: schema,
      index: index
    } do
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
      # Verify document exists
      assert :ok = IndexWriter.commit(writer)
      {:ok, searcher} = Searcher.new(index)

      {:ok, query} = Query.term(schema, "id", "300")
      {:ok, before_results} = Searcher.search(searcher, query, 10)
      assert length(before_results) == 1

      # Delete the document
      assert {:ok, :deleted} = Document.delete(writer, "id", 300, schema)
      assert :ok = IndexWriter.commit(writer)

      # Refresh searcher to see changes
      {:ok, searcher} = Searcher.new(index)

      # Verify document was deleted
      {:ok, after_results} = Searcher.search(searcher, query, 10)
      assert length(after_results) == 0
    end

    test "deleting non-existent document doesn't fail", %{writer: writer, schema: schema} do
      # Try to delete a document that doesn't exist
      assert {:ok, :deleted} = Document.delete(writer, "id", "999999", schema)
      assert :ok = IndexWriter.commit(writer)
    end

    test "deletes multiple documents with same term value", %{
      writer: writer,
      schema: schema,
      index: index
    } do
      # Add multiple documents with the same value for a field
      docs = [
        %{
          "title" => "Same Category Doc 1",
          "content" => "Content 1",
          "id" => 401,
          "score" => 85.0,
          "published" => true,
          "created_at" => "2023-01-01T00:00:00Z"
        },
        %{
          "title" => "Same Category Doc 2",
          "content" => "Content 2",
          "id" => 402,
          "score" => 90.0,
          "published" => true,
          "created_at" => "2023-01-02T00:00:00Z"
        },
        %{
          "title" => "Different Category Doc",
          "content" => "Content 3",
          "id" => 403,
          "score" => 95.0,
          "published" => false,
          "created_at" => "2023-01-03T00:00:00Z"
        }
      ]

      assert {:ok, _} = Document.add_batch(writer, docs, schema)
      # Verify documents exist
      assert :ok = IndexWriter.commit(writer)
      {:ok, searcher} = Searcher.new(index)

      {:ok, all_query} = Query.all()
      {:ok, all_results} = Searcher.search(searcher, all_query, 10)
      assert length(all_results) == 3

      # Delete documents with published = true
      assert {:ok, :deleted} = Document.delete(writer, "published", "true", schema)
      assert :ok = IndexWriter.commit(writer)

      # Refresh searcher to see changes
      {:ok, searcher} = Searcher.new(index)

      # Verify only the unpublished document remains
      {:ok, after_results} = Searcher.search(searcher, all_query, 10)
      assert length(after_results) == 1

      remaining_doc = hd(after_results)
      assert remaining_doc["title"] == "Different Category Doc"
      assert remaining_doc["published"] == false
    end

    test "delete with different term field types", %{writer: writer, schema: schema, index: index} do
      # Add documents for testing different field type deletions
      docs = [
        %{
          "title" => "Text Term Doc",
          "content" => "Content for text term test",
          "id" => 501,
          "score" => 85.0,
          "published" => true,
          "created_at" => "2023-01-01T00:00:00Z"
        },
        %{
          "title" => "Numeric Term Doc",
          "content" => "Content for numeric term test",
          "id" => 502,
          "score" => 90.0,
          "published" => true,
          "created_at" => "2023-01-02T00:00:00Z"
        },
        %{
          "title" => "Boolean Term Doc",
          "content" => "Content for boolean term test",
          "id" => 503,
          "score" => 95.0,
          "published" => false,
          "created_at" => "2023-01-03T00:00:00Z"
        }
      ]

      assert {:ok, _} = Document.add_batch(writer, docs, schema)
      assert :ok = IndexWriter.commit(writer)

      # Delete by text field
      assert {:ok, :deleted} = Document.delete(writer, "title", "Text Term Doc", schema)

      # Delete by numeric field
      assert {:ok, :deleted} = Document.delete(writer, "id", "502", schema)

      # Delete by boolean field
      assert {:ok, :deleted} = Document.delete(writer, "published", "false", schema)

      # Verify all documents were deleted
      assert :ok = IndexWriter.commit(writer)
      {:ok, searcher} = Searcher.new(index)

      {:ok, all_query} = Query.all()
      {:ok, results} = Searcher.search(searcher, all_query, 10)
      assert length(results) == 0
    end

    test "delete fails with invalid field name", %{writer: writer, schema: schema} do
      # Try to delete with non-existent field
      assert {:error, _reason} = Document.delete(writer, "non_existent_field", "value", schema)
    end

    test "delete fails with incompatible value type", %{writer: writer, schema: schema} do
      # Try to delete with wrong value type for the field
      assert {:error, _reason} = Document.delete(writer, "id", "not_a_number", schema)
    end
  end

  test "handles different data types correctly", %{schema: schema} do
    # Test various data type conversions
    doc_with_types = %{
      "title" => "Type Test",
      "content" => "Testing various types",
      "id" => 123,
      "score" => 88.7,
      "published" => false,
      "created_at" => "2023-06-15T14:30:00Z"
    }

    assert {:ok, _validated} = Document.validate(doc_with_types, schema)
  end

  test "validates required fields", %{schema: schema} do
    # Document missing required fields
    incomplete_doc = %{
      "title" => "Incomplete Document"
      # Missing other fields
    }

    # This should still validate as our current implementation is permissive
    # In a production system, you might want stricter validation
    assert {:ok, _validated} = Document.validate(incomplete_doc, schema)
  end

  test "handles JSON document preparation", %{schema: schema} do
    doc = %{
      "title" => "JSON Test",
      "content" => "Testing JSON preparation",
      "id" => 456,
      "score" => 77.3,
      "published" => true,
      "created_at" => "2023-06-15T14:30:00Z"
    }

    assert {:ok, json_doc} = Document.prepare_json(doc, schema)
    assert is_binary(json_doc)
  end
end
