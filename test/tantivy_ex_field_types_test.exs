defmodule TantivyEx.SchemaFieldTypesTest do
  @moduledoc """
  Comprehensive tests for all field types and schema introspection functionality.
  """
  use ExUnit.Case, async: true

  alias TantivyEx.Schema

  describe "field type support" do
    test "adds i64 field to schema" do
      schema = Schema.new()

      schema = Schema.add_i64_field(schema, "age", :indexed)
      field_names = Schema.get_field_names(schema)

      assert "age" in field_names
      assert {:ok, "i64"} = Schema.get_field_type(schema, "age")
    end

    test "adds f64 field to schema" do
      schema = Schema.new()

      schema = Schema.add_f64_field(schema, "price", :stored)
      field_names = Schema.get_field_names(schema)

      assert "price" in field_names
      assert {:ok, "f64"} = Schema.get_field_type(schema, "price")
    end

    test "adds bool field to schema" do
      schema = Schema.new()

      schema = Schema.add_bool_field(schema, "is_active", :fast)
      field_names = Schema.get_field_names(schema)

      assert "is_active" in field_names
      assert {:ok, "bool"} = Schema.get_field_type(schema, "is_active")
    end

    test "adds date field to schema" do
      schema = Schema.new()

      schema = Schema.add_date_field(schema, "created_at", :indexed_stored)
      field_names = Schema.get_field_names(schema)

      assert "created_at" in field_names
      assert {:ok, "date"} = Schema.get_field_type(schema, "created_at")
    end

    test "adds facet field to schema" do
      schema = Schema.new()

      schema = Schema.add_facet_field(schema, "category")
      field_names = Schema.get_field_names(schema)

      assert "category" in field_names
      assert {:ok, "facet"} = Schema.get_field_type(schema, "category")
    end

    test "adds bytes field to schema" do
      schema = Schema.new()

      schema = Schema.add_bytes_field(schema, "binary_data", :stored)
      field_names = Schema.get_field_names(schema)

      assert "binary_data" in field_names
      assert {:ok, "bytes"} = Schema.get_field_type(schema, "binary_data")
    end

    test "adds json field to schema" do
      schema = Schema.new()

      schema = Schema.add_json_field(schema, "metadata", :stored)
      field_names = Schema.get_field_names(schema)

      assert "metadata" in field_names
      assert {:ok, "json"} = Schema.get_field_type(schema, "metadata")
    end

    test "adds ip_addr field to schema" do
      schema = Schema.new()

      schema = Schema.add_ip_addr_field(schema, "client_ip", :indexed)
      field_names = Schema.get_field_names(schema)

      assert "client_ip" in field_names
      assert {:ok, "ip_addr"} = Schema.get_field_type(schema, "client_ip")
    end

    test "adds text field with tokenizer placeholder" do
      schema = Schema.new()

      schema = Schema.add_text_field_with_tokenizer(schema, "content", :text, "simple")
      field_names = Schema.get_field_names(schema)

      assert "content" in field_names
      assert {:ok, "text"} = Schema.get_field_type(schema, "content")
    end
  end

  describe "field option variations" do
    test "supports different numeric field options" do
      schema = Schema.new()

      schema = Schema.add_i64_field(schema, "indexed_field", :indexed)
      schema = Schema.add_i64_field(schema, "stored_field", :stored)
      schema = Schema.add_i64_field(schema, "fast_field", :fast)
      schema = Schema.add_i64_field(schema, "indexed_stored_field", :indexed_stored)
      schema = Schema.add_i64_field(schema, "fast_stored_field", :fast_stored)

      field_names = Schema.get_field_names(schema)

      assert "indexed_field" in field_names
      assert "stored_field" in field_names
      assert "fast_field" in field_names
      assert "indexed_stored_field" in field_names
      assert "fast_stored_field" in field_names
    end

    test "supports different text field options" do
      schema = Schema.new()

      schema = Schema.add_text_field(schema, "text_field", :text)
      schema = Schema.add_text_field(schema, "stored_field", :stored)
      schema = Schema.add_text_field(schema, "text_stored_field", :text_stored)

      field_names = Schema.get_field_names(schema)

      assert "text_field" in field_names
      assert "stored_field" in field_names
      assert "text_stored_field" in field_names
    end
  end

  describe "schema introspection" do
    test "returns empty field names for new schema" do
      schema = Schema.new()
      field_names = Schema.get_field_names(schema)

      assert field_names == []
    end

    test "returns all field names in complex schema" do
      schema = Schema.new()

      schema = Schema.add_text_field(schema, "title", :text_stored)
      schema = Schema.add_i64_field(schema, "count", :indexed)
      schema = Schema.add_f64_field(schema, "score", :fast)
      schema = Schema.add_bool_field(schema, "active", :stored)
      schema = Schema.add_date_field(schema, "timestamp", :indexed_stored)

      field_names = Schema.get_field_names(schema)

      assert length(field_names) == 5
      assert "title" in field_names
      assert "count" in field_names
      assert "score" in field_names
      assert "active" in field_names
      assert "timestamp" in field_names
    end

    test "returns correct field types" do
      schema = Schema.new()

      schema = Schema.add_text_field(schema, "title", :text)
      schema = Schema.add_u64_field(schema, "id", :indexed)
      schema = Schema.add_i64_field(schema, "count", :stored)
      schema = Schema.add_f64_field(schema, "price", :fast)
      schema = Schema.add_bool_field(schema, "active", :indexed)
      schema = Schema.add_date_field(schema, "created", :stored)
      schema = Schema.add_facet_field(schema, "category")
      schema = Schema.add_bytes_field(schema, "data", :stored)
      schema = Schema.add_json_field(schema, "metadata", :stored)
      schema = Schema.add_ip_addr_field(schema, "ip", :indexed)

      assert {:ok, "text"} = Schema.get_field_type(schema, "title")
      assert {:ok, "u64"} = Schema.get_field_type(schema, "id")
      assert {:ok, "i64"} = Schema.get_field_type(schema, "count")
      assert {:ok, "f64"} = Schema.get_field_type(schema, "price")
      assert {:ok, "bool"} = Schema.get_field_type(schema, "active")
      assert {:ok, "date"} = Schema.get_field_type(schema, "created")
      assert {:ok, "facet"} = Schema.get_field_type(schema, "category")
      assert {:ok, "bytes"} = Schema.get_field_type(schema, "data")
      assert {:ok, "json"} = Schema.get_field_type(schema, "metadata")
      assert {:ok, "ip_addr"} = Schema.get_field_type(schema, "ip")
    end

    test "returns error for non-existent field" do
      schema = Schema.new()

      schema = Schema.add_text_field(schema, "title", :text)

      assert {:error, _reason} = Schema.get_field_type(schema, "non_existent")
    end

    test "validates schema successfully" do
      schema = Schema.new()

      schema = Schema.add_text_field(schema, "title", :text)

      assert {:ok, message} = Schema.validate(schema)
      assert message =~ "Schema is valid with 1 fields"
    end

    test "validates empty schema fails" do
      schema = Schema.new()

      assert {:error, reason} = Schema.validate(schema)
      assert reason =~ "Schema must have at least one field"
    end

    test "validates complex schema" do
      schema = Schema.new()

      schema = Schema.add_text_field(schema, "title", :text)
      schema = Schema.add_u64_field(schema, "id", :indexed)
      schema = Schema.add_date_field(schema, "created", :stored)

      assert {:ok, message} = Schema.validate(schema)
      assert message =~ "Schema is valid with 3 fields"
    end
  end

  describe "schema building workflow" do
    test "builds comprehensive schema with all field types" do
      schema = Schema.new()

      # Add text fields
      schema = Schema.add_text_field(schema, "title", :text_stored)
      schema = Schema.add_text_field(schema, "description", :text)

      # Add numeric fields
      schema = Schema.add_u64_field(schema, "id", :indexed_stored)
      schema = Schema.add_i64_field(schema, "score", :fast)
      schema = Schema.add_f64_field(schema, "price", :fast_stored)

      # Add other field types
      schema = Schema.add_bool_field(schema, "is_published", :indexed)
      schema = Schema.add_date_field(schema, "created_at", :indexed_stored)
      schema = Schema.add_facet_field(schema, "category")
      schema = Schema.add_bytes_field(schema, "thumbnail", :stored)
      schema = Schema.add_json_field(schema, "metadata", :stored)
      schema = Schema.add_ip_addr_field(schema, "user_ip", :indexed)

      # Validate the complete schema
      field_names = Schema.get_field_names(schema)
      assert length(field_names) == 11

      # Validate field types
      expected_fields = %{
        "title" => "text",
        "description" => "text",
        "id" => "u64",
        "score" => "i64",
        "price" => "f64",
        "is_published" => "bool",
        "created_at" => "date",
        "category" => "facet",
        "thumbnail" => "bytes",
        "metadata" => "json",
        "user_ip" => "ip_addr"
      }

      for {field_name, expected_type} <- expected_fields do
        assert field_name in field_names
        assert {:ok, ^expected_type} = Schema.get_field_type(schema, field_name)
      end

      # Validate the schema
      assert {:ok, message} = Schema.validate(schema)
      assert message =~ "Schema is valid with 11 fields"
    end
  end

  describe "error handling" do
    test "handles invalid field options gracefully" do
      schema = Schema.new()

      # These should still work but might fall back to default options
      schema = Schema.add_i64_field(schema, "test", :invalid_option)
      field_names = Schema.get_field_names(schema)

      assert "test" in field_names
      assert {:ok, "i64"} = Schema.get_field_type(schema, "test")
    end
  end

  describe "custom tokenizer support" do
    test "creates text field with custom tokenizer" do
      schema = Schema.new()

      # Add a text field with a custom tokenizer
      schema = Schema.add_text_field_with_tokenizer(schema, "content", :text, "custom_ngram")
      field_names = Schema.get_field_names(schema)

      assert "content" in field_names
      assert {:ok, "text"} = Schema.get_field_type(schema, "content")
    end

    test "creates stored text field with custom tokenizer" do
      schema = Schema.new()

      # Add a stored text field with a custom tokenizer
      schema = Schema.add_text_field_with_tokenizer(schema, "title", :text_stored, "en_stem")
      field_names = Schema.get_field_names(schema)

      assert "title" in field_names
      assert {:ok, "text"} = Schema.get_field_type(schema, "title")
    end

    test "creates stored-only text field (no tokenizer applied)" do
      schema = Schema.new()

      # Add a stored-only text field - tokenizer should be ignored
      schema =
        Schema.add_text_field_with_tokenizer(schema, "raw_content", :stored, "ignored_tokenizer")

      field_names = Schema.get_field_names(schema)

      assert "raw_content" in field_names
      assert {:ok, "text"} = Schema.get_field_type(schema, "raw_content")
    end

    test "handles various custom tokenizer names" do
      schema = Schema.new()

      # Test with various tokenizer names
      tokenizers = ["default", "raw", "en_stem", "whitespace", "custom_tokenizer", "ngram_3"]

      # Use Enum.reduce to properly accumulate the schema changes
      final_schema =
        Enum.with_index(tokenizers)
        |> Enum.reduce(schema, fn {tokenizer_name, field_suffix}, acc_schema ->
          field_name = "field_#{field_suffix}"
          Schema.add_text_field_with_tokenizer(acc_schema, field_name, :text, tokenizer_name)
        end)

      field_names = Schema.get_field_names(final_schema)
      assert length(field_names) == 6

      # Verify all fields are text type
      for {_tokenizer_name, field_suffix} <- Enum.with_index(tokenizers) do
        field_name = "field_#{field_suffix}"
        assert field_name in field_names
        assert {:ok, "text"} = Schema.get_field_type(final_schema, field_name)
      end
    end

    test "integrates custom tokenizer fields with schema validation" do
      schema =
        Schema.new()
        |> Schema.add_text_field_with_tokenizer("title", :text_stored, "en_stem")
        |> Schema.add_text_field_with_tokenizer("body", :text, "custom_ngram")
        |> Schema.add_text_field_with_tokenizer("metadata", :stored, "raw")
        |> Schema.add_u64_field("id", :indexed)

      # Validate the complete schema
      assert {:ok, message} = Schema.validate(schema)
      assert message =~ "Schema is valid with 4 fields"

      # Check all field types
      field_names = Schema.get_field_names(schema)
      assert length(field_names) == 4

      assert {:ok, "text"} = Schema.get_field_type(schema, "title")
      assert {:ok, "text"} = Schema.get_field_type(schema, "body")
      assert {:ok, "text"} = Schema.get_field_type(schema, "metadata")
      assert {:ok, "u64"} = Schema.get_field_type(schema, "id")
    end
  end
end
