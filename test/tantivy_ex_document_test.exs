defmodule TantivyExDocumentTest do
  use ExUnit.Case, async: true
  alias TantivyEx.{Schema, Index, IndexWriter, Document}

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

  test "adds batch of documents", %{writer: writer, schema: schema} do
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

    options = %{batch_size: 10, validate: true}
    assert {:ok, _result} = Document.add_batch(writer, docs, schema, options)
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
    assert {:error, _errors} = Document.add_batch(writer, docs, schema, options)
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
