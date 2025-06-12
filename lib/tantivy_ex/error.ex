defmodule TantivyEx.Error do
  @moduledoc """
  Comprehensive error handling for TantivyEx with structured error types
  that mirror Tantivy's Rust error hierarchy.

  This module provides proper Elixir error types and messages for all TantivyEx
  operations, offering better error diagnostics and handling capabilities.

  ## Error Types

  All errors implement the Elixir `Exception` behavior and provide structured
  error information with context, suggestions, and categorization.

  ### Core Error Categories

  - `AggregationError` - Errors during aggregation operations
  - `IoError` - File system and I/O related errors
  - `LockError` - Index locking and concurrency errors
  - `FieldError` - Schema field-related errors
  - `ValidationError` - Document and data validation errors
  - `SchemaError` - Schema definition and compatibility errors
  - `SystemError` - System resource and configuration errors
  - `QueryError` - Query parsing and execution errors
  - `IndexError` - Index creation and management errors
  - `MemoryError` - Memory management and limits errors
  - `ConcurrencyError` - Thread pool and parallelism errors

  ## Usage

      # Match on specific error types
      case TantivyEx.Document.add(writer, doc, schema) do
        {:ok, result} -> handle_success(result)
        {:error, %TantivyEx.Error.ValidationError{} = error} -> handle_validation_error(error)
        {:error, %TantivyEx.Error.MemoryError{} = error} -> handle_memory_error(error)
        {:error, error} -> handle_generic_error(error)
      end

      # Get error details
      error = %TantivyEx.Error.FieldError{
        message: "Field 'title' not found in schema",
        field: "title",
        operation: :search,
        suggestion: "Check field name or add field to schema"
      }

      IO.puts(Exception.message(error))
      # => "Field error in search operation: Field 'title' not found in schema. Suggestion: Check field name or add field to schema"

  ## Error Enhancement

  All TantivyEx modules should use `TantivyEx.Error.wrap/2` to convert raw
  errors into structured error types:

      case Native.some_operation(args) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> {:error, TantivyEx.Error.wrap(reason, :operation_context)}
      end
  """

  # Define all error exception modules

  defmodule AggregationError do
    @moduledoc """
    Errors that occur during aggregation operations.
    """
    defexception [:message, :aggregation_type, :field, :operation, :suggestion, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            aggregation_type: String.t() | nil,
            field: String.t() | nil,
            operation: atom() | nil,
            suggestion: String.t() | nil,
            details: map() | nil
          }

    @impl Exception
    def message(%__MODULE__{} = error) do
      base = "Aggregation error"

      base =
        if error.operation, do: "#{base} in #{error.operation} operation", else: base

      base = "#{base}: #{error.message}"

      base =
        if error.suggestion, do: "#{base}. Suggestion: #{error.suggestion}", else: base

      base
    end
  end

  defmodule IoError do
    @moduledoc """
    File system and I/O related errors.
    """
    defexception [:message, :path, :operation, :os_error, :suggestion, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            path: String.t() | nil,
            operation: atom() | nil,
            os_error: String.t() | nil,
            suggestion: String.t() | nil,
            details: map() | nil
          }

    @impl Exception
    def message(%__MODULE__{} = error) do
      base = "I/O error"

      base =
        if error.operation, do: "#{base} in #{error.operation} operation", else: base

      base = "#{base}: #{error.message}"

      base =
        if error.path, do: "#{base} (path: #{error.path})", else: base

      base =
        if error.suggestion, do: "#{base}. Suggestion: #{error.suggestion}", else: base

      base
    end
  end

  defmodule LockError do
    @moduledoc """
    Index locking and concurrency errors.
    """
    defexception [:message, :lock_type, :index_path, :operation, :timeout, :suggestion, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            lock_type: String.t() | nil,
            index_path: String.t() | nil,
            operation: atom() | nil,
            timeout: non_neg_integer() | nil,
            suggestion: String.t() | nil,
            details: map() | nil
          }

    @impl Exception
    def message(%__MODULE__{} = error) do
      base = "Lock error"

      base =
        if error.operation, do: "#{base} in #{error.operation} operation", else: base

      base = "#{base}: #{error.message}"

      base =
        if error.timeout, do: "#{base} (timeout: #{error.timeout}ms)", else: base

      base =
        if error.suggestion, do: "#{base}. Suggestion: #{error.suggestion}", else: base

      base
    end
  end

  defmodule FieldError do
    @moduledoc """
    Schema field-related errors.
    """
    defexception [
      :message,
      :field,
      :field_type,
      :operation,
      :available_fields,
      :suggestion,
      :details
    ]

    @type t :: %__MODULE__{
            message: String.t(),
            field: String.t() | nil,
            field_type: String.t() | nil,
            operation: atom() | nil,
            available_fields: [String.t()] | nil,
            suggestion: String.t() | nil,
            details: map() | nil
          }

    @impl Exception
    def message(%__MODULE__{} = error) do
      base = "Field error"

      base =
        if error.operation, do: "#{base} in #{error.operation} operation", else: base

      base = "#{base}: #{error.message}"

      base =
        if error.available_fields && length(error.available_fields) > 0,
          do: "#{base}. Available fields: #{Enum.join(error.available_fields, ", ")}",
          else: base

      base =
        if error.suggestion, do: "#{base}. Suggestion: #{error.suggestion}", else: base

      base
    end
  end

  defmodule ValidationError do
    @moduledoc """
    Document and data validation errors.
    """
    defexception [:message, :field, :value, :expected_type, :operation, :suggestion, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            field: String.t() | nil,
            value: any() | nil,
            expected_type: String.t() | nil,
            operation: atom() | nil,
            suggestion: String.t() | nil,
            details: map() | nil
          }

    @impl Exception
    def message(%__MODULE__{} = error) do
      base = "Validation error"

      base =
        if error.operation, do: "#{base} in #{error.operation} operation", else: base

      base = "#{base}: #{error.message}"

      base =
        if error.expected_type,
          do: "#{base} (expected: #{error.expected_type})",
          else: base

      base =
        if error.suggestion, do: "#{base}. Suggestion: #{error.suggestion}", else: base

      base
    end
  end

  defmodule SchemaError do
    @moduledoc """
    Schema definition and compatibility errors.
    """
    defexception [:message, :schema_version, :operation, :incompatibility, :suggestion, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            schema_version: String.t() | nil,
            operation: atom() | nil,
            incompatibility: String.t() | nil,
            suggestion: String.t() | nil,
            details: map() | nil
          }

    @impl Exception
    def message(%__MODULE__{} = error) do
      base = "Schema error"

      base =
        if error.operation, do: "#{base} in #{error.operation} operation", else: base

      base = "#{base}: #{error.message}"

      base =
        if error.incompatibility,
          do: "#{base} (incompatibility: #{error.incompatibility})",
          else: base

      base =
        if error.suggestion, do: "#{base}. Suggestion: #{error.suggestion}", else: base

      base
    end
  end

  defmodule SystemError do
    @moduledoc """
    System resource and configuration errors.
    """
    defexception [
      :message,
      :resource_type,
      :operation,
      :available_resources,
      :suggestion,
      :details
    ]

    @type t :: %__MODULE__{
            message: String.t(),
            resource_type: String.t() | nil,
            operation: atom() | nil,
            available_resources: map() | nil,
            suggestion: String.t() | nil,
            details: map() | nil
          }

    @impl Exception
    def message(%__MODULE__{} = error) do
      base = "System error"

      base =
        if error.operation, do: "#{base} in #{error.operation} operation", else: base

      base = "#{base}: #{error.message}"

      base =
        if error.suggestion, do: "#{base}. Suggestion: #{error.suggestion}", else: base

      base
    end
  end

  defmodule QueryError do
    @moduledoc """
    Query parsing and execution errors.
    """
    defexception [:message, :query, :parser_type, :operation, :position, :suggestion, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            query: String.t() | nil,
            parser_type: String.t() | nil,
            operation: atom() | nil,
            position: non_neg_integer() | nil,
            suggestion: String.t() | nil,
            details: map() | nil
          }

    @impl Exception
    def message(%__MODULE__{} = error) do
      base = "Query error"

      base =
        if error.operation, do: "#{base} in #{error.operation} operation", else: base

      base = "#{base}: #{error.message}"

      base =
        if error.position, do: "#{base} (at position #{error.position})", else: base

      base =
        if error.suggestion, do: "#{base}. Suggestion: #{error.suggestion}", else: base

      base
    end
  end

  defmodule IndexError do
    @moduledoc """
    Index creation and management errors.
    """
    defexception [:message, :index_path, :operation, :index_version, :suggestion, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            index_path: String.t() | nil,
            operation: atom() | nil,
            index_version: String.t() | nil,
            suggestion: String.t() | nil,
            details: map() | nil
          }

    @impl Exception
    def message(%__MODULE__{} = error) do
      base = "Index error"

      base =
        if error.operation, do: "#{base} in #{error.operation} operation", else: base

      base = "#{base}: #{error.message}"

      base =
        if error.index_path, do: "#{base} (path: #{error.index_path})", else: base

      base =
        if error.suggestion, do: "#{base}. Suggestion: #{error.suggestion}", else: base

      base
    end
  end

  defmodule MemoryError do
    @moduledoc """
    Memory management and limits errors.
    """
    defexception [:message, :operation, :memory_used, :memory_limit, :suggestion, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            operation: atom() | nil,
            memory_used: non_neg_integer() | nil,
            memory_limit: non_neg_integer() | nil,
            suggestion: String.t() | nil,
            details: map() | nil
          }

    @impl Exception
    def message(%__MODULE__{} = error) do
      base = "Memory error"

      base =
        if error.operation, do: "#{base} in #{error.operation} operation", else: base

      base = "#{base}: #{error.message}"

      base =
        if error.memory_used && error.memory_limit,
          do: "#{base} (used: #{error.memory_used}MB, limit: #{error.memory_limit}MB)",
          else: base

      base =
        if error.suggestion, do: "#{base}. Suggestion: #{error.suggestion}", else: base

      base
    end
  end

  defmodule ConcurrencyError do
    @moduledoc """
    Thread pool and parallelism errors.
    """
    defexception [:message, :operation, :thread_count, :max_threads, :suggestion, :details]

    @type t :: %__MODULE__{
            message: String.t(),
            operation: atom() | nil,
            thread_count: non_neg_integer() | nil,
            max_threads: non_neg_integer() | nil,
            suggestion: String.t() | nil,
            details: map() | nil
          }

    @impl Exception
    def message(%__MODULE__{} = error) do
      base = "Concurrency error"

      base =
        if error.operation, do: "#{base} in #{error.operation} operation", else: base

      base = "#{base}: #{error.message}"

      base =
        if error.max_threads,
          do: "#{base} (max threads: #{error.max_threads})",
          else: base

      base =
        if error.suggestion, do: "#{base}. Suggestion: #{error.suggestion}", else: base

      base
    end
  end

  # Main error wrapping and handling functions

  @doc """
  Wraps a raw error into a structured TantivyEx error.

  This function analyzes the error content and context to determine the most
  appropriate error type and provides enhanced error information.

  ## Parameters

  - `error` - The raw error (string, atom, or map)
  - `context` - The operation context (atom) for better error categorization

  ## Examples

      iex> TantivyEx.Error.wrap("Field 'title' not found", :search)
      %TantivyEx.Error.FieldError{
        message: "Field 'title' not found",
        field: "title",
        operation: :search,
        suggestion: "Check field name or add field to schema"
      }

      iex> TantivyEx.Error.wrap("Memory limit exceeded", :indexing)
      %TantivyEx.Error.MemoryError{
        message: "Memory limit exceeded",
        operation: :indexing,
        suggestion: "Increase memory limit or reduce batch size"
      }
  """
  @spec wrap(any(), atom()) :: Exception.t()
  def wrap(error, context \\ :unknown)

  def wrap(error_string, context) when is_binary(error_string) do
    error_string
    |> String.downcase()
    |> categorize_error(context, error_string)
  end

  def wrap(error_atom, context) when is_atom(error_atom) do
    error_atom
    |> Atom.to_string()
    |> wrap(context)
  end

  def wrap(%{} = error_map, context) do
    message = Map.get(error_map, :message, "Unknown error")
    wrap(message, context)
  end

  def wrap(error, context) do
    %SystemError{
      message: "Unexpected error format: #{inspect(error)}",
      operation: context,
      suggestion: "Report this error to TantivyEx maintainers"
    }
  end

  # Private error categorization functions

  defp categorize_error(error_string, context, original_message) do
    cond do
      # Memory-related errors
      String.contains?(error_string, ["memory", "limit", "allocation", "oom"]) ->
        create_memory_error(original_message, context)

      # Query errors (check before validation errors to catch "invalid query")
      String.contains?(error_string, ["query", "parse", "syntax", "invalid query"]) or
          (String.contains?(error_string, ["invalid"]) and
             String.contains?(error_string, ["query", "syntax"])) ->
        create_query_error(original_message, context)

      # Validation errors (but not query-related ones)
      String.contains?(error_string, ["validation", "invalid", "type", "format"]) and
          not String.contains?(error_string, ["query", "syntax"]) ->
        create_validation_error(original_message, context)

      # Field-related errors (more specific patterns to avoid conflicts)
      String.contains?(error_string, ["field", "not found", "does not exist"]) and
          not String.contains?(error_string, ["invalid", "type"]) ->
        create_field_error(original_message, context, error_string)

      # I/O errors
      String.contains?(error_string, ["file", "directory", "permission", "not found", "io"]) ->
        create_io_error(original_message, context)

      # Lock errors
      String.contains?(error_string, ["lock", "concurrency", "timeout", "busy"]) ->
        create_lock_error(original_message, context)

      # Schema errors
      String.contains?(error_string, ["schema", "incompatible", "version"]) ->
        create_schema_error(original_message, context)

      # Aggregation errors
      String.contains?(error_string, ["aggregation", "agg", "bucket", "metric"]) ->
        create_aggregation_error(original_message, context)

      # Index errors
      String.contains?(error_string, ["index", "corrupt", "missing"]) ->
        create_index_error(original_message, context)

      # Concurrency errors
      String.contains?(error_string, ["thread", "parallel", "concurrent"]) ->
        create_concurrency_error(original_message, context)

      # Default to system error
      true ->
        %SystemError{
          message: original_message,
          operation: context,
          suggestion: determine_generic_suggestion(context)
        }
    end
  end

  defp create_memory_error(message, context) do
    %MemoryError{
      message: message,
      operation: context,
      suggestion: determine_memory_suggestion(context)
    }
  end

  defp create_field_error(message, context, error_string) do
    field = extract_field_name(error_string)

    %FieldError{
      message: message,
      field: field,
      operation: context,
      suggestion: determine_field_suggestion(field, context)
    }
  end

  defp create_io_error(message, context) do
    %IoError{
      message: message,
      operation: context,
      suggestion: determine_io_suggestion(context)
    }
  end

  defp create_lock_error(message, context) do
    %LockError{
      message: message,
      operation: context,
      suggestion: determine_lock_suggestion(context)
    }
  end

  defp create_query_error(message, context) do
    %QueryError{
      message: message,
      operation: context,
      suggestion: determine_query_suggestion(context)
    }
  end

  defp create_schema_error(message, context) do
    %SchemaError{
      message: message,
      operation: context,
      suggestion: determine_schema_suggestion(context)
    }
  end

  defp create_validation_error(message, context) do
    %ValidationError{
      message: message,
      operation: context,
      suggestion: determine_validation_suggestion(context)
    }
  end

  defp create_aggregation_error(message, context) do
    %AggregationError{
      message: message,
      operation: context,
      suggestion: determine_aggregation_suggestion(context)
    }
  end

  defp create_index_error(message, context) do
    %IndexError{
      message: message,
      operation: context,
      suggestion: determine_index_suggestion(context)
    }
  end

  defp create_concurrency_error(message, context) do
    %ConcurrencyError{
      message: message,
      operation: context,
      suggestion: determine_concurrency_suggestion(context)
    }
  end

  # Suggestion generators based on context and error type

  defp determine_memory_suggestion(context) do
    case context do
      :indexing -> "Increase memory limit or reduce batch size"
      :search -> "Reduce result limit or simplify query"
      :aggregation -> "Use fewer aggregations or sample data"
      _ -> "Increase available memory or reduce operation size"
    end
  end

  defp determine_field_suggestion(field, context) do
    case {context, field} do
      {:search, field} when field != nil -> "Check field name '#{field}' or add field to schema"
      {:search, _} -> "Check field name or add field to schema"
      {:aggregation, field} when field != nil -> "Ensure field '#{field}' exists and is indexed"
      {:aggregation, _} -> "Ensure field exists and is indexed"
      {_, field} when field != nil -> "Verify field '#{field}' is defined in schema"
      {_, _} -> "Verify field is defined in schema"
    end
  end

  defp determine_io_suggestion(context) do
    case context do
      :indexing -> "Check file permissions and disk space"
      :search -> "Verify index path exists and is readable"
      _ -> "Check file system permissions and paths"
    end
  end

  defp determine_lock_suggestion(context) do
    case context do
      :indexing -> "Ensure only one writer per index or increase timeout"
      :search -> "Retry operation or check for long-running writes"
      _ -> "Retry operation or check for competing processes"
    end
  end

  defp determine_query_suggestion(context) do
    case context do
      :search -> "Check query syntax and field names"
      :aggregation -> "Verify aggregation query structure"
      _ -> "Review query syntax and available fields"
    end
  end

  defp determine_schema_suggestion(_context) do
    "Ensure schema compatibility or recreate index with new schema"
  end

  defp determine_validation_suggestion(context) do
    case context do
      :indexing -> "Check document field types and values"
      :search -> "Verify search parameters and types"
      _ -> "Validate input data against schema requirements"
    end
  end

  defp determine_aggregation_suggestion(_context) do
    "Check aggregation configuration and field types"
  end

  defp determine_index_suggestion(context) do
    case context do
      :creation -> "Check index path and permissions"
      :opening -> "Verify index exists and is not corrupted"
      _ -> "Check index integrity and compatibility"
    end
  end

  defp determine_concurrency_suggestion(_context) do
    "Reduce thread count or increase system resources"
  end

  defp determine_generic_suggestion(context) do
    case context do
      :indexing -> "Check document format and index configuration"
      :search -> "Verify query format and index availability"
      :aggregation -> "Check aggregation configuration"
      _ -> "Review operation parameters and system resources"
    end
  end

  # Helper functions

  defp extract_field_name(error_string) do
    # Try to extract field name from error messages like "Field 'title' not found"
    case Regex.run(~r/field\s*'([^']+)'/i, error_string) do
      [_, field_name] -> field_name
      _ -> nil
    end
  end

  @doc """
  Checks if an error is retryable based on its type and context.

  ## Examples

      iex> TantivyEx.Error.retryable?(%TantivyEx.Error.LockError{})
      true

      iex> TantivyEx.Error.retryable?(%TantivyEx.Error.SchemaError{})
      false
  """
  @spec retryable?(Exception.t()) :: boolean()
  def retryable?(%LockError{}), do: true
  def retryable?(%IoError{os_error: os_error}) when os_error in ["EAGAIN", "EBUSY"], do: true
  def retryable?(%MemoryError{}), do: true
  def retryable?(%ConcurrencyError{}), do: true
  def retryable?(%SystemError{resource_type: "temporary"}), do: true
  def retryable?(_), do: false

  @doc """
  Returns the severity level of an error.

  ## Examples

      iex> TantivyEx.Error.severity(%TantivyEx.Error.ValidationError{})
      :warning

      iex> TantivyEx.Error.severity(%TantivyEx.Error.SystemError{})
      :error
  """
  @spec severity(Exception.t()) :: :info | :warning | :error | :critical
  def severity(%ValidationError{}), do: :warning
  def severity(%FieldError{}), do: :warning
  def severity(%QueryError{}), do: :warning
  def severity(%MemoryError{}), do: :error
  def severity(%IoError{}), do: :error
  def severity(%LockError{}), do: :error
  def severity(%SchemaError{}), do: :error
  def severity(%IndexError{}), do: :critical
  def severity(%SystemError{}), do: :critical
  def severity(%AggregationError{}), do: :warning
  def severity(%ConcurrencyError{}), do: :error
  def severity(_), do: :error

  @doc """
  Converts an error to a loggable format with structured metadata.

  ## Examples

      iex> error = %TantivyEx.Error.FieldError{field: "title", operation: :search}
      iex> TantivyEx.Error.to_log_format(error)
      %{
        level: :warning,
        message: "Field error in search operation",
        category: "field_error",
        field: "title",
        operation: :search,
        retryable: false
      }
  """
  @spec to_log_format(Exception.t()) :: map()
  def to_log_format(error) do
    base_metadata = %{
      level: severity(error),
      message: Exception.message(error),
      category: error_category(error),
      retryable: retryable?(error)
    }

    error_specific_metadata = extract_error_metadata(error)
    Map.merge(base_metadata, error_specific_metadata)
  end

  # Extract error-specific metadata for logging
  defp extract_error_metadata(%FieldError{} = error) do
    %{field: error.field, operation: error.operation}
  end

  defp extract_error_metadata(%MemoryError{} = error) do
    %{
      operation: error.operation,
      memory_used: error.memory_used,
      memory_limit: error.memory_limit
    }
  end

  defp extract_error_metadata(%QueryError{} = error) do
    %{operation: error.operation, parser_type: error.parser_type}
  end

  defp extract_error_metadata(%IoError{} = error) do
    %{operation: error.operation, path: error.path}
  end

  defp extract_error_metadata(%LockError{} = error) do
    %{operation: error.operation, lock_type: error.lock_type, timeout: error.timeout}
  end

  defp extract_error_metadata(%ConcurrencyError{} = error) do
    %{
      operation: error.operation,
      thread_count: error.thread_count,
      max_threads: error.max_threads
    }
  end

  defp extract_error_metadata(error) do
    if Map.has_key?(error, :operation) do
      %{operation: error.operation}
    else
      %{}
    end
  end

  defp error_category(%module{}) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end
