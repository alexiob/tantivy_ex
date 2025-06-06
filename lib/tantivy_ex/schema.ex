defmodule TantivyEx.Schema do
  @moduledoc """
  Schema management for TantivyEx.

  A schema defines the structure of documents in an index, including field names,
  types, and indexing options.

  ## Field Types

  TantivyEx supports all Tantivy field types:

  - **Text fields**: Full-text searchable fields with tokenization
  - **Numeric fields**: u64, i64, f64 for numbers
  - **Boolean fields**: true/false values
  - **Date fields**: DateTime values with precision control
  - **Facet fields**: Hierarchical categorization
  - **Bytes fields**: Binary data storage
  - **JSON fields**: Structured JSON object indexing
  - **IP Address fields**: IPv4 and IPv6 addresses

  ## Field Options

  Each field type supports different indexing and storage options:

  - `:stored` - Field values are stored and retrievable
  - `:indexed` - Field is searchable (creates inverted index)
  - `:fast` - Field supports fast field access (like Lucene DocValues)
  - `:text` - Text field is tokenized and indexed for full-text search
  - `:text_stored` - Text field is tokenized, indexed, and stored

  ## Fast Fields

  Fast fields enable rapid access to field values by document ID, useful for:
  - Sorting and scoring during search
  - Faceted search and aggregations
  - Range queries and filtering
  - Custom collectors that need field access
  """

  alias TantivyEx.Native

  @type t :: reference()

  @type text_field_options ::
          :text
          | :text_stored
          | :stored

  @type numeric_field_options ::
          :indexed
          | :indexed_stored
          | :stored
          | :fast
          | :fast_stored

  @type field_options :: text_field_options() | numeric_field_options()

  @doc """
  Creates a new empty schema.

  ## Examples

      iex> schema = TantivyEx.Schema.new()
      iex> is_reference(schema)
      true
  """
  @spec new() :: t()
  def new do
    Native.schema_builder_new()
  end

  @doc """
  Adds a text field to the schema.

  Text fields are used for full-text search with tokenization and analysis.

  ## Parameters

  - `schema`: The schema to modify
  - `field_name`: The name of the field
  - `options`: Field indexing and storage options

  ## Field Options

  - `:text` - Field is tokenized and indexed for full-text search
  - `:text_stored` - Field is tokenized, indexed, and stored for retrieval
  - `:stored` - Field is only stored (not searchable)
  - `:fast` - Field is tokenized, indexed, and optimized for fast access
  - `:fast_stored` - Field is tokenized, indexed with positions, stored, and optimized for fast access and phrase queries

  ## Examples

      iex> schema = TantivyEx.Schema.new()
      iex> schema = TantivyEx.Schema.add_text_field(schema, "title", :text_stored)
      iex> schema = TantivyEx.Schema.add_text_field(schema, "body", :text)
      iex> is_reference(schema)
      true
  """
  @spec add_text_field(t(), String.t(), text_field_options()) :: t()
  def add_text_field(schema, field_name, options) when is_atom(options) do
    options_str =
      case options do
        :text -> "TEXT"
        :text_stored -> "TEXT_STORED"
        :stored -> "STORED"
        :fast -> "FAST"
        :fast_stored -> "FAST_STORED"
        _ -> "TEXT"
      end

    case Native.schema_add_text_field(schema, field_name, options_str) do
      {:ok, new_schema} -> new_schema
      {:error, reason} -> raise "Failed to add text field: #{reason}"
      # Direct return for now
      new_schema -> new_schema
    end
  end

  def add_text_field(schema, field_name, options) when is_binary(options) do
    case Native.schema_add_text_field(schema, field_name, options) do
      {:ok, new_schema} -> new_schema
      {:error, reason} -> raise "Failed to add text field: #{reason}"
      # Direct return for now
      new_schema -> new_schema
    end
  end

  @doc """
  Adds a text field with a custom tokenizer to the schema.

  ## Parameters

  - `schema`: The schema to modify
  - `field_name`: The name of the field
  - `options`: Field indexing and storage options
  - `tokenizer`: The tokenizer to use ("default", "raw", "en_stem", etc.)

  ## Examples

      iex> schema = TantivyEx.Schema.new()
      iex> schema = TantivyEx.Schema.add_text_field_with_tokenizer(schema, "title", :text_stored, "en_stem")
      iex> is_reference(schema)
      true
  """
  @spec add_text_field_with_tokenizer(t(), String.t(), text_field_options(), String.t()) :: t()
  def add_text_field_with_tokenizer(schema, field_name, options, tokenizer)
      when is_atom(options) do
    options_str =
      case options do
        :text -> "TEXT"
        :text_stored -> "TEXT_STORED"
        :stored -> "STORED"
        _ -> "TEXT"
      end

    case Native.schema_add_text_field_with_tokenizer(schema, field_name, options_str, tokenizer) do
      {:ok, new_schema} -> new_schema
      {:error, reason} -> raise "Failed to add text field with tokenizer: #{reason}"
      new_schema -> new_schema
    end
  end

  @doc """
  Adds a u64 (unsigned 64-bit integer) field to the schema.

  ## Parameters

  - `schema`: The schema to modify
  - `field_name`: The name of the field
  - `options`: Field indexing and storage options

  ## Field Options

  - `:indexed` - Field is indexed for fast filtering and range queries
  - `:indexed_stored` - Field is indexed and stored for retrieval
  - `:stored` - Field is only stored (not searchable)
  - `:fast` - Field is stored as a fast field for rapid access
  - `:fast_stored` - Field is both fast and stored

  ## Examples

      iex> schema = TantivyEx.Schema.new()
      iex> schema = TantivyEx.Schema.add_u64_field(schema, "price", :indexed_stored)
      iex> schema = TantivyEx.Schema.add_u64_field(schema, "views", :fast)
      iex> is_reference(schema)
      true
  """
  @spec add_u64_field(t(), String.t(), numeric_field_options()) :: t()
  def add_u64_field(schema, field_name, options) when is_atom(options) do
    options_str =
      case options do
        :indexed -> "INDEXED"
        :indexed_stored -> "INDEXED_STORED"
        :stored -> "STORED"
        :fast -> "FAST"
        :fast_stored -> "FAST_STORED"
        _ -> "INDEXED"
      end

    case Native.schema_add_u64_field(schema, field_name, options_str) do
      {:ok, new_schema} -> new_schema
      {:error, reason} -> raise "Failed to add u64 field: #{reason}"
      # Direct return for now
      new_schema -> new_schema
    end
  end

  def add_u64_field(schema, field_name, options) when is_binary(options) do
    case Native.schema_add_u64_field(schema, field_name, options) do
      {:ok, new_schema} -> new_schema
      {:error, reason} -> raise "Failed to add u64 field: #{reason}"
      # Direct return for now
      new_schema -> new_schema
    end
  end

  @doc """
  Adds an i64 (signed 64-bit integer) field to the schema.

  Useful for signed integers, timestamps, and other numeric data.

  ## Examples

      iex> schema = TantivyEx.Schema.new()
      iex> schema = TantivyEx.Schema.add_i64_field(schema, "timestamp", :fast_stored)
      iex> is_reference(schema)
      true
  """
  @spec add_i64_field(t(), String.t(), numeric_field_options()) :: t()
  def add_i64_field(schema, field_name, options) when is_atom(options) do
    options_str =
      case options do
        :indexed -> "INDEXED"
        :indexed_stored -> "INDEXED_STORED"
        :stored -> "STORED"
        :fast -> "FAST"
        :fast_stored -> "FAST_STORED"
        _ -> "INDEXED"
      end

    case Native.schema_add_i64_field(schema, field_name, options_str) do
      {:ok, new_schema} -> new_schema
      {:error, reason} -> raise "Failed to add i64 field: #{reason}"
      new_schema -> new_schema
    end
  end

  @doc """
  Adds an f64 (64-bit floating point) field to the schema.

  Useful for prices, ratings, scores, and other decimal values.

  ## Examples

      iex> schema = TantivyEx.Schema.new()
      iex> schema = TantivyEx.Schema.add_f64_field(schema, "rating", :fast_stored)
      iex> is_reference(schema)
      true
  """
  @spec add_f64_field(t(), String.t(), numeric_field_options()) :: t()
  def add_f64_field(schema, field_name, options) when is_atom(options) do
    options_str =
      case options do
        :indexed -> "INDEXED"
        :indexed_stored -> "INDEXED_STORED"
        :stored -> "STORED"
        :fast -> "FAST"
        :fast_stored -> "FAST_STORED"
        _ -> "INDEXED"
      end

    case Native.schema_add_f64_field(schema, field_name, options_str) do
      {:ok, new_schema} -> new_schema
      {:error, reason} -> raise "Failed to add f64 field: #{reason}"
      new_schema -> new_schema
    end
  end

  @doc """
  Adds a boolean field to the schema.

  Useful for flags, status indicators, and binary choices.

  ## Examples

      iex> schema = TantivyEx.Schema.new()
      iex> schema = TantivyEx.Schema.add_bool_field(schema, "published", :indexed_stored)
      iex> is_reference(schema)
      true
  """
  @spec add_bool_field(t(), String.t(), numeric_field_options()) :: t()
  def add_bool_field(schema, field_name, options) when is_atom(options) do
    options_str =
      case options do
        :indexed -> "INDEXED"
        :indexed_stored -> "INDEXED_STORED"
        :stored -> "STORED"
        :fast -> "FAST"
        :fast_stored -> "FAST_STORED"
        _ -> "INDEXED"
      end

    case Native.schema_add_bool_field(schema, field_name, options_str) do
      {:ok, new_schema} -> new_schema
      {:error, reason} -> raise "Failed to add bool field: #{reason}"
      new_schema -> new_schema
    end
  end

  @doc """
  Adds a date field to the schema.

  Useful for timestamps, publication dates, and temporal data.

  ## Examples

      iex> schema = TantivyEx.Schema.new()
      iex> schema = TantivyEx.Schema.add_date_field(schema, "created_at", :fast_stored)
      iex> is_reference(schema)
      true
  """
  @spec add_date_field(t(), String.t(), numeric_field_options()) :: t()
  def add_date_field(schema, field_name, options) when is_atom(options) do
    options_str =
      case options do
        :indexed -> "INDEXED"
        :indexed_stored -> "INDEXED_STORED"
        :stored -> "STORED"
        :fast -> "FAST"
        :fast_stored -> "FAST_STORED"
        _ -> "INDEXED"
      end

    case Native.schema_add_date_field(schema, field_name, options_str) do
      {:ok, new_schema} -> new_schema
      {:error, reason} -> raise "Failed to add date field: #{reason}"
      new_schema -> new_schema
    end
  end

  @doc """
  Adds a facet field to the schema.

  Facet fields enable hierarchical categorization and faceted search.
  Facets are always indexed and stored by design.

  ## Examples

      iex> schema = TantivyEx.Schema.new()
      iex> schema = TantivyEx.Schema.add_facet_field(schema, "category")
      iex> is_reference(schema)
      true
  """
  @spec add_facet_field(t(), String.t()) :: t()
  def add_facet_field(schema, field_name) do
    case Native.schema_add_facet_field(schema, field_name, "") do
      {:ok, new_schema} -> new_schema
      {:error, reason} -> raise "Failed to add facet field: #{reason}"
      new_schema -> new_schema
    end
  end

  @doc """
  Adds a bytes field to the schema.

  Useful for binary data, hashes, and raw byte sequences.

  ## Examples

      iex> schema = TantivyEx.Schema.new()
      iex> schema = TantivyEx.Schema.add_bytes_field(schema, "file_hash", :stored)
      iex> is_reference(schema)
      true
  """
  @spec add_bytes_field(t(), String.t(), numeric_field_options()) :: t()
  def add_bytes_field(schema, field_name, options) when is_atom(options) do
    options_str =
      case options do
        :indexed -> "INDEXED"
        :indexed_stored -> "INDEXED_STORED"
        :stored -> "STORED"
        :fast -> "FAST"
        :fast_stored -> "FAST_STORED"
        # Default to stored for bytes
        _ -> "STORED"
      end

    case Native.schema_add_bytes_field(schema, field_name, options_str) do
      {:ok, new_schema} -> new_schema
      {:error, reason} -> raise "Failed to add bytes field: #{reason}"
      new_schema -> new_schema
    end
  end

  @doc """
  Adds a JSON object field to the schema.

  JSON fields allow indexing and searching within structured JSON data.

  ## Examples

      iex> schema = TantivyEx.Schema.new()
      iex> schema = TantivyEx.Schema.add_json_field(schema, "metadata", :text_stored)
      iex> is_reference(schema)
      true
  """
  @spec add_json_field(t(), String.t(), text_field_options()) :: t()
  def add_json_field(schema, field_name, options) when is_atom(options) do
    options_str =
      case options do
        :text -> "TEXT"
        :text_stored -> "TEXT_STORED"
        :stored -> "STORED"
        _ -> "TEXT"
      end

    case Native.schema_add_json_field(schema, field_name, options_str) do
      {:ok, new_schema} -> new_schema
      {:error, reason} -> raise "Failed to add JSON field: #{reason}"
      new_schema -> new_schema
    end
  end

  @doc """
  Adds an IP address field to the schema.

  Supports both IPv4 and IPv6 addresses for network data indexing.

  ## Examples

      iex> schema = TantivyEx.Schema.new()
      iex> schema = TantivyEx.Schema.add_ip_addr_field(schema, "client_ip", :indexed_stored)
      iex> is_reference(schema)
      true
  """
  @spec add_ip_addr_field(t(), String.t(), numeric_field_options()) :: t()
  def add_ip_addr_field(schema, field_name, options) when is_atom(options) do
    options_str =
      case options do
        :indexed -> "INDEXED"
        :indexed_stored -> "INDEXED_STORED"
        :stored -> "STORED"
        :fast -> "FAST"
        :fast_stored -> "FAST_STORED"
        _ -> "INDEXED"
      end

    case Native.schema_add_ip_addr_field(schema, field_name, options_str) do
      {:ok, new_schema} -> new_schema
      {:error, reason} -> raise "Failed to add IP address field: #{reason}"
      new_schema -> new_schema
    end
  end

  @doc """
  Returns a list of all field names in the schema.

  ## Examples

      iex> schema = TantivyEx.Schema.new()
      iex> schema = TantivyEx.Schema.add_text_field(schema, "title", :text_stored)
      iex> schema = TantivyEx.Schema.add_u64_field(schema, "price", :indexed)
      iex> TantivyEx.Schema.get_field_names(schema)
      ["title", "price"]
  """
  @spec get_field_names(t()) :: [String.t()]
  def get_field_names(schema) do
    Native.schema_get_field_names(schema)
  end

  @doc """
  Returns the type of a specific field in the schema.

  ## Examples

      iex> schema = TantivyEx.Schema.new()
      iex> schema = TantivyEx.Schema.add_text_field(schema, "title", :text_stored)
      iex> TantivyEx.Schema.get_field_type(schema, "title")
      {:ok, "text"}

      iex> TantivyEx.Schema.get_field_type(schema, "nonexistent")
      {:error, "Field 'nonexistent' not found"}
  """
  @spec get_field_type(t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def get_field_type(schema, field_name) do
    case Native.schema_get_field_type(schema, field_name) do
      {:ok, field_type} -> {:ok, field_type}
      {:error, reason} -> {:error, reason}
      field_type when is_binary(field_type) -> {:ok, field_type}
    end
  end

  @doc """
  Validates a schema for correctness.

  Checks for basic requirements like having at least one field.

  ## Examples

      iex> schema = TantivyEx.Schema.new()
      iex> TantivyEx.Schema.validate(schema)
      {:error, "Schema must have at least one field"}

      iex> schema = TantivyEx.Schema.add_text_field(schema, "title", :text)
      iex> TantivyEx.Schema.validate(schema)
      {:ok, "Schema is valid"}
  """
  @spec validate(t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate(schema) do
    case Native.schema_validate(schema) do
      {:ok, message} -> {:ok, message}
      {:error, reason} -> {:error, reason}
      message when is_binary(message) -> {:ok, message}
    end
  end

  @doc """
  Checks if a field exists in the schema.

  ## Parameters

  - `schema`: The schema to check
  - `field_name`: The name of the field to check for

  ## Examples

      iex> TantivyEx.Schema.field_exists?(schema, "title")
      true
      iex> TantivyEx.Schema.field_exists?(schema, "nonexistent_field")
      false
  """
  @spec field_exists?(t(), String.t()) :: boolean()
  def field_exists?(schema, field_name) when is_binary(field_name) do
    # Get all field names and check if the given field_name is among them
    field_names = Native.schema_get_field_names(schema)
    Enum.member?(field_names, field_name)
  end
end
