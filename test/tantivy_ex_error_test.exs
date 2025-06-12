defmodule TantivyEx.ErrorTest do
  use ExUnit.Case, async: true
  alias TantivyEx.Error

  describe "error wrapping" do
    test "wraps field errors correctly" do
      error = Error.wrap("Field 'title' not found", :search)

      assert %Error.FieldError{} = error
      assert error.message == "Field 'title' not found"
      assert error.field == "title"
      assert error.operation == :search
      assert error.suggestion == "Check field name 'title' or add field to schema"
    end

    test "wraps memory errors correctly" do
      error = Error.wrap("Memory limit exceeded", :indexing)

      assert %Error.MemoryError{} = error
      assert error.message == "Memory limit exceeded"
      assert error.operation == :indexing
      assert error.suggestion == "Increase memory limit or reduce batch size"
    end

    test "wraps query errors correctly" do
      error = Error.wrap("Invalid query syntax", :search)

      assert %Error.QueryError{} = error
      assert error.message == "Invalid query syntax"
      assert error.operation == :search
      assert error.suggestion == "Check query syntax and field names"
    end

    test "wraps validation errors correctly" do
      error = Error.wrap("Invalid field type", :indexing)

      assert %Error.ValidationError{} = error
      assert error.message == "Invalid field type"
      assert error.operation == :indexing
      assert error.suggestion == "Check document field types and values"
    end

    test "wraps unknown errors as system errors" do
      error = Error.wrap("Some unknown error", :unknown)

      assert %Error.SystemError{} = error
      assert error.message == "Some unknown error"
      assert error.operation == :unknown
    end

    test "handles error atoms" do
      error = Error.wrap(:field_not_found, :search)

      assert %Error.FieldError{} = error
      assert error.message == "field_not_found"
      assert error.operation == :search
    end

    test "handles error maps" do
      error_map = %{message: "Custom error message"}
      error = Error.wrap(error_map, :indexing)

      assert %Error.SystemError{} = error
      assert error.message == "Custom error message"
      assert error.operation == :indexing
    end
  end

  describe "error messages" do
    test "formats field error messages" do
      error = %Error.FieldError{
        message: "Field not found",
        field: "title",
        operation: :search,
        available_fields: ["body", "id"],
        suggestion: "Check field name"
      }

      message = Exception.message(error)

      assert message =~ "Field error in search operation"
      assert message =~ "Field not found"
      assert message =~ "Available fields: body, id"
      assert message =~ "Suggestion: Check field name"
    end

    test "formats memory error messages" do
      error = %Error.MemoryError{
        message: "Memory limit exceeded",
        operation: :indexing,
        memory_used: 1024,
        memory_limit: 512,
        suggestion: "Increase memory limit"
      }

      message = Exception.message(error)

      assert message =~ "Memory error in indexing operation"
      assert message =~ "Memory limit exceeded"
      assert message =~ "used: 1024MB, limit: 512MB"
      assert message =~ "Suggestion: Increase memory limit"
    end
  end

  describe "error utilities" do
    test "determines retryable errors" do
      assert Error.retryable?(%Error.LockError{})
      assert Error.retryable?(%Error.MemoryError{})
      assert Error.retryable?(%Error.ConcurrencyError{})
      refute Error.retryable?(%Error.SchemaError{})
      refute Error.retryable?(%Error.ValidationError{})
    end

    test "determines error severity" do
      assert Error.severity(%Error.ValidationError{}) == :warning
      assert Error.severity(%Error.FieldError{}) == :warning
      assert Error.severity(%Error.MemoryError{}) == :error
      assert Error.severity(%Error.SystemError{}) == :critical
      assert Error.severity(%Error.IndexError{}) == :critical
    end

    test "converts errors to log format" do
      error = %Error.FieldError{
        message: "Field error",
        field: "title",
        operation: :search
      }

      log_format = Error.to_log_format(error)

      assert log_format.level == :warning
      assert log_format.category == "field_error"
      assert log_format.field == "title"
      assert log_format.operation == :search
      refute log_format.retryable
    end
  end
end
