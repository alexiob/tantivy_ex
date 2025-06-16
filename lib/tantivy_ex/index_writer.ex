defmodule TantivyEx.IndexWriter do
  @moduledoc """
  IndexWriter for adding documents to a TantivyEx index.

  The IndexWriter is responsible for adding documents to an index and committing
  changes to make them searchable.
  """

  alias TantivyEx.{Native, Index, Query}

  @type t :: reference()

  @doc """
  Creates a new IndexWriter for the given index.

  ## Parameters

  - `index`: The index to write to
  - `memory_budget`: Memory budget in bytes (default: 50MB)

  ## Examples

      iex> schema = TantivyEx.Schema.new()
      iex> schema = TantivyEx.Schema.add_text_field(schema, "title", :text_stored)
      iex> {:ok, index} = TantivyEx.Index.create_in_ram(schema)
      iex> {:ok, writer} = TantivyEx.IndexWriter.new(index)
      iex> is_reference(writer)
      true
  """
  @spec new(Index.t(), pos_integer()) :: {:ok, t()} | {:error, String.t()}
  def new(index, memory_budget \\ 50_000_000) do
    # Ensure minimum memory budget (Tantivy requires at least 15MB)
    min_budget = 15_000_000
    actual_budget = max(memory_budget, min_budget)

    case Native.index_writer(index, actual_budget) do
      {:error, reason} -> {:error, reason}
      writer -> {:ok, writer}
    end
  rescue
    e -> {:error, "Failed to create index writer: #{inspect(e)}"}
  end

  @doc """
  Adds a document to the index.

  The document should be a map where keys are field names and values
  are the field values. The field names should match those defined in the schema.

  ## Parameters

  - `writer`: The IndexWriter
  - `document`: A map representing the document to add

  ## Examples

      iex> # Assuming writer is already created
      iex> document = %{"title" => "Hello World", "body" => "This is a test document"}
      iex> :ok = TantivyEx.IndexWriter.add_document(writer, document)
      :ok
  """
  @spec add_document(t(), map()) :: :ok | {:error, String.t()}
  def add_document(writer, document) when is_map(document) do
    case Native.writer_add_document(writer, document) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
      # Temporary handling
      _ -> :ok
    end
  rescue
    e -> {:error, "Failed to add document: #{inspect(e)}"}
  end

  @doc """
  Commits all pending changes to the index.

  After calling commit, all added documents become searchable.
  This operation flushes the current segment to disk.

  ## Parameters

  - `writer`: The IndexWriter

  ## Examples

      iex> :ok = TantivyEx.IndexWriter.commit(writer)
      :ok
  """
  @spec commit(t()) :: :ok | {:error, String.t()}
  def commit(writer) do
    case Native.writer_commit(writer) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
      # Temporary handling
      _ -> :ok
    end
  rescue
    e -> {:error, "Failed to commit: #{inspect(e)}"}
  end

  @doc """
  Deletes all documents matching the given query.

  This operation marks documents for deletion but does not make the
  deletions visible until the writer is committed.

  ## Parameters

  - `writer`: The IndexWriter
  - `query`: A TantivyEx.Query to match documents to delete

  ## Examples

      iex> query = TantivyEx.Query.term(schema, "status", "inactive")
      iex> :ok = TantivyEx.IndexWriter.delete_documents(writer, query)
      :ok
  """
  @spec delete_documents(t(), Query.t()) :: :ok | {:error, String.t()}
  def delete_documents(writer, query) do
    case Native.writer_delete_documents(writer, query) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  rescue
    e -> {:error, "Failed to delete documents: #{inspect(e)}"}
  end

  @doc """
  Deletes all documents in the index.

  This operation marks all documents for deletion but does not make the
  deletions visible until the writer is committed.

  ## Parameters

  - `writer`: The IndexWriter

  ## Examples

      iex> :ok = TantivyEx.IndexWriter.delete_all_documents(writer)
      :ok
      iex> :ok = TantivyEx.IndexWriter.commit(writer)
      :ok
  """
  @spec delete_all_documents(t()) :: :ok | {:error, String.t()}
  def delete_all_documents(writer) do
    case Native.writer_delete_all_documents(writer) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  rescue
    e -> {:error, "Failed to delete all documents: #{inspect(e)}"}
  end

  @doc """
  Rolls back any pending changes and cancels the current operation.

  This should be called when errors occur during a batch index operation
  to avoid partial updates.

  ## Parameters

  - `writer`: The IndexWriter

  ## Examples

      iex> :ok = TantivyEx.IndexWriter.rollback(writer)
      :ok
  """
  @spec rollback(t()) :: :ok | {:error, String.t()}
  def rollback(writer) do
    case Native.writer_rollback(writer) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  rescue
    e -> {:error, "Failed to rollback: #{inspect(e)}"}
  end
end
