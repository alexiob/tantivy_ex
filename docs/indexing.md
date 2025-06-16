# Indexing Guide

This comprehensive guide covers document indexing strategies, batch operations, performance optimization, and best practices for efficiently managing your search data with TantivyEx.

## Related Documentation

- **[Document Operations Guide](documents.md)** - Detailed guide to working with documents, validation, and field types
- **[Schema Design Guide](schema.md)** - Design effective schemas for your search use case
- **[Search Guide](search.md)** - Query your indexed data effectively
- **[Search Results Guide](search_results.md)** - Process and enhance search results

## Table of Contents

- [Understanding Indexing](#understanding-indexing)
- [Basic Indexing Operations](#basic-indexing-operations)
- [Document Structure & Validation](#document-structure--validation)
- [Batch Operations & Performance](#batch-operations--performance)
- [Index Management](#index-management)
- [Advanced Indexing Patterns](#advanced-indexing-patterns)
- [Error Handling & Recovery](#error-handling--recovery)
- [Production Best Practices](#production-best-practices)

## Understanding Indexing

### What is Indexing?

**Indexing** is the process of transforming your raw documents into a specialized data structure optimized for fast search operations. When you index a document, TantivyEx:

1. **Analyzes text fields** using tokenizers to break text into searchable terms
2. **Builds inverted indexes** that map terms to documents containing them
3. **Creates fast access structures** for numeric and faceted data
4. **Stores field values** (if configured) for retrieval in search results

### The Indexing Lifecycle

```text
Raw Document → Validation → Analysis → Storage → Commit → Searchable
```

1. **Raw Document**: Your application data (maps, structs)
2. **Validation**: Ensuring document matches schema
3. **Analysis**: Text processing and tokenization
4. **Storage**: Writing to index files
5. **Commit**: Making changes visible to search
6. **Searchable**: Available for queries

### When to Index vs. Store

Understanding the difference between indexing and storing is crucial:

- **Indexed fields**: Searchable but may not be retrievable
- **Stored fields**: Retrievable in search results
- **Indexed + Stored**: Both searchable and retrievable (most common)

```elixir
# Examples of different field configurations
schema = Schema.add_text_field(schema, "searchable_only", :text)      # Index only
schema = Schema.add_text_field(schema, "display_only", :stored)      # Store only
schema = Schema.add_text_field(schema, "full_featured", :text_stored) # Both
```

## Basic Indexing Operations

### Creating an Index

```elixir
alias TantivyEx.{Index, Schema}

# 1. Design your schema
schema = Schema.new()
schema = Schema.add_text_field(schema, "title", :text_stored)
schema = Schema.add_text_field(schema, "content", :text)
schema = Schema.add_u64_field(schema, "timestamp", :fast_stored)
schema = Schema.add_f64_field(schema, "rating", :fast_stored)

# 2. Create or open index

# Recommended: Open existing or create new (production-ready)
{:ok, index} = Index.open_or_create("/var/lib/myapp/search_index", schema)

# Alternative: Create new index (fails if exists)
{:ok, index} = Index.create_in_dir("/var/lib/myapp/search_index", schema)

# Open existing index (fails if doesn't exist)
{:ok, index} = Index.open("/var/lib/myapp/search_index")

# For testing - temporary memory storage
{:ok, index} = Index.create_in_ram(schema)

# 3. Or create/open existing index
{:ok, index} = Index.create_in_dir("/var/lib/myapp/search_index", schema)
```

### Adding Single Documents

```elixir
# Basic document addition
{:ok, writer} = TantivyEx.IndexWriter.new(index)

document = %{
  "title" => "Getting Started with Elixir",
  "content" => "Elixir is a dynamic, functional programming language...",
  "timestamp" => System.system_time(:second),
  "rating" => 4.5
}

case TantivyEx.IndexWriter.add_document(writer, document) do
  :ok ->
    IO.puts("Document added successfully")
    # Remember to commit to make it searchable!
    TantivyEx.IndexWriter.commit(writer)

  {:error, reason} ->
    IO.puts("Failed to add document: #{inspect(reason)}")
end
```

### Making Changes Visible

```elixir
# Documents are not searchable until committed
{:ok, writer} = TantivyEx.IndexWriter.new(index)
:ok = TantivyEx.IndexWriter.add_document(writer, doc1)
:ok = TantivyEx.IndexWriter.add_document(writer, doc2)
:ok = TantivyEx.IndexWriter.add_document(writer, doc3)

# Now make all additions searchable
:ok = TantivyEx.IndexWriter.commit(writer)

# You can search immediately after commit
{:ok, searcher} = TantivyEx.Searcher.new(index)
{:ok, results} = TantivyEx.Searcher.search(searcher, "elixir", 10)
```

### Document Updates and Deletions

TantivyEx supports both additive operations and document deletion:

```elixir
alias TantivyEx.{Index, IndexWriter, Query, Schema}

# 1. Create or open an existing index
{:ok, index} = Index.open_or_create("/path/to/index", schema)
{:ok, writer} = IndexWriter.new(index)

# 2. Delete documents matching a query
{:ok, inactive_query} = Query.term(schema, "active", false)
:ok = IndexWriter.delete_documents(writer, inactive_query)

# 3. Delete all documents from the index
:ok = IndexWriter.delete_all_documents(writer)

# 4. Commit changes to make deletions visible
:ok = IndexWriter.commit(writer)

# 5. Rollback pending changes if needed
:ok = IndexWriter.add_document(writer, doc)
# If you decide not to add this document:
:ok = IndexWriter.rollback(writer)
```

For document updates (which TantivyEx doesn't support natively), you can:

```elixir
# Pattern for document updates with unique ID
defmodule MyApp.DocumentManager do
  def update_document(index, doc_id, updated_doc) do
    {:ok, writer} = IndexWriter.new(index)

    # 1. Delete the existing document by ID
    {:ok, id_query} = Query.term(schema, "id", doc_id)
    :ok = IndexWriter.delete_documents(writer, id_query)

    # 2. Add the updated document
    :ok = IndexWriter.add_document(writer, updated_doc)

    # 3. Commit both operations
    :ok = IndexWriter.commit(writer)
  end
end
```

## Document Structure & Validation

### Schema Compliance

All documents must conform to your schema. Here's how to ensure compliance:

```elixir
defmodule MyApp.DocumentValidator do
  def validate_document(document, schema) do
    with {:ok, field_names} <- Schema.get_field_names(schema),
         :ok <- check_required_fields(document, field_names),
         :ok <- validate_field_types(document, schema) do
      {:ok, document}
    else
      {:error, reason} -> {:error, "Document validation failed: #{reason}"}
    end
  end

  defp check_required_fields(document, schema_fields) do
    # Define your required fields
    required_fields = ["title", "content", "timestamp"]
    document_fields = Map.keys(document)
    missing_fields = required_fields -- document_fields

    case missing_fields do
      [] -> :ok
      missing -> {:error, "Missing required fields: #{inspect(missing)}"}
    end
  end

  defp validate_field_types(document, schema) do
    Enum.reduce_while(document, :ok, fn {field, value}, acc ->
      case validate_field_value(field, value, schema) do
        :ok -> {:cont, acc}
        {:error, reason} -> {:halt, {:error, "Field #{field}: #{reason}"}}
      end
    end)
  end

  defp validate_field_value(field, value, schema) do
    # Get field info from schema and validate value type
    case Schema.get_field_info(schema, field) do
      {:ok, %{type: "text"}} when is_binary(value) -> :ok
      {:ok, %{type: "u64"}} when is_integer(value) and value >= 0 -> :ok
      {:ok, %{type: "f64"}} when is_number(value) -> :ok
      {:ok, %{type: type}} -> {:error, "Invalid type for #{type} field"}
      {:error, _} -> {:error, "Unknown field"}
    end
  end
end
```

### Data Type Conversion

Convert your application data to index-compatible formats:

```elixir
defmodule MyApp.DocumentConverter do
  def prepare_for_indexing(raw_document) do
    %{
      # Text fields - ensure strings
      "title" => to_string(raw_document.title),
      "content" => to_string(raw_document.content),

      # Numeric fields - ensure proper types
      "user_id" => raw_document.user_id |> ensure_integer(),
      "rating" => raw_document.rating |> ensure_float(),

      # Timestamps - convert to Unix seconds
      "created_at" => raw_document.created_at |> to_unix_timestamp(),
      "updated_at" => raw_document.updated_at |> to_unix_timestamp(),

      # Facets - ensure proper hierarchical format
      "category" => format_facet_path(raw_document.category),

      # JSON fields - ensure proper encoding
      "metadata" => prepare_json_field(raw_document.metadata)
    }
  end

  defp ensure_integer(value) when is_integer(value), do: value
  defp ensure_integer(value) when is_binary(value), do: String.to_integer(value)
  defp ensure_integer(value), do: raise("Cannot convert #{inspect(value)} to integer")

  defp ensure_float(value) when is_float(value), do: value
  defp ensure_float(value) when is_integer(value), do: value * 1.0
  defp ensure_float(value) when is_binary(value), do: String.to_float(value)
  defp ensure_float(value), do: raise("Cannot convert #{inspect(value)} to float")

  defp to_unix_timestamp(%DateTime{} = dt), do: DateTime.to_unix(dt)
  defp to_unix_timestamp(%NaiveDateTime{} = ndt) do
    ndt |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
  end
  defp to_unix_timestamp(timestamp) when is_integer(timestamp), do: timestamp

  defp format_facet_path(categories) when is_list(categories) do
    "/" <> Enum.join(categories, "/")
  end
  defp format_facet_path(category) when is_binary(category) do
    if String.starts_with?(category, "/"), do: category, else: "/" <> category
  end

  defp prepare_json_field(data) when is_map(data), do: data
  defp prepare_json_field(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, parsed} -> parsed
      {:error, _} -> %{"raw" => data}
    end
  end
  defp prepare_json_field(data), do: %{"value" => data}
end
```

## Batch Operations & Performance

### High-Performance Bulk Indexing

For large datasets, efficient batching is essential:

```elixir
defmodule MyApp.BulkIndexer do
  alias TantivyEx.Index

  @batch_size 1000
  @commit_interval 10_000  # Commit every 10k documents

  def index_documents(index, documents) do
    start_time = System.monotonic_time(:millisecond)
    total_docs = length(documents)

    IO.puts("Starting bulk indexing of #{total_docs} documents...")

    result =
      documents
      |> Stream.with_index()
      |> Stream.chunk_every(@batch_size)
      |> Enum.reduce({:ok, 0}, fn batch, {:ok, processed} ->
        case process_batch(index, batch, processed) do
          {:ok, batch_count} ->
            new_processed = processed + batch_count
            log_progress(new_processed, total_docs, start_time)
            {:ok, new_processed}

          {:error, reason} ->
            {:error, {reason, processed}}
        end
      end)

    case result do
      {:ok, processed} ->
        # Final commit
        {:ok, writer} = TantivyEx.IndexWriter.new(index)
        :ok = TantivyEx.IndexWriter.commit(writer)

        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time
        docs_per_sec = (processed * 1000) / duration

        IO.puts("Indexing complete: #{processed} docs in #{duration}ms (#{Float.round(docs_per_sec, 2)} docs/sec)")
        {:ok, processed}

      {:error, {reason, processed}} ->
        IO.puts("Indexing failed after #{processed} documents: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_batch(index, batch, total_processed) do
    batch_start = System.monotonic_time(:millisecond)
    {:ok, writer} = TantivyEx.IndexWriter.new(index)

    result = Enum.reduce_while(batch, {:ok, 0}, fn {doc, _index}, {:ok, count} ->
      case TantivyEx.IndexWriter.add_document(writer, doc) do
        :ok -> {:cont, {:ok, count + 1}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)

    case result do
      {:ok, batch_count} ->
        # Periodic commits for large datasets
        if rem(total_processed + batch_count, @commit_interval) == 0 do
          TantivyEx.IndexWriter.commit(writer)
        end

        batch_end = System.monotonic_time(:millisecond)
        batch_duration = batch_end - batch_start

        IO.puts("Batch processed: #{batch_count} docs in #{batch_duration}ms")
        {:ok, batch_count}

      error -> error
    end
  end

  defp log_progress(processed, total, start_time) do
    current_time = System.monotonic_time(:millisecond)
    elapsed = current_time - start_time

    if elapsed > 0 do
      docs_per_sec = (processed * 1000) / elapsed
      percentage = (processed / total) * 100

      IO.puts("Progress: #{processed}/#{total} (#{Float.round(percentage, 1)}%) - #{Float.round(docs_per_sec, 2)} docs/sec")
    end
  end
end
```

### Memory-Efficient Streaming

For extremely large datasets, use streaming to avoid memory issues:

```elixir
defmodule MyApp.StreamingIndexer do
  alias TantivyEx.Index

  def index_from_database(index, query, batch_size \\ 1000) do
    {:ok, writer} = TantivyEx.IndexWriter.new(index)

    MyApp.Repo.stream(query)
    |> Stream.map(&MyApp.DocumentConverter.prepare_for_indexing/1)
    |> Stream.chunk_every(batch_size)
    |> Enum.each(fn batch ->
      Enum.each(batch, &TantivyEx.IndexWriter.add_document(writer, &1))
      TantivyEx.IndexWriter.commit(writer)  # Frequent commits for streaming
    end)
  end

  def index_from_csv(index, csv_path, batch_size \\ 1000) do
    {:ok, writer} = TantivyEx.IndexWriter.new(index)

    csv_path
    |> File.stream!()
    |> CSV.decode!(headers: true)
    |> Stream.map(&convert_csv_row/1)
    |> Stream.chunk_every(batch_size)
    |> Enum.each(fn batch ->
      Enum.each(batch, &TantivyEx.IndexWriter.add_document(writer, &1))
      TantivyEx.IndexWriter.commit(writer)
    end)
  end

  defp convert_csv_row(row) do
    %{
      "title" => row["title"],
      "content" => row["content"],
      "timestamp" => String.to_integer(row["timestamp"]),
      "rating" => String.to_float(row["rating"] || "0.0")
    }
  end
end
```

### Optimizing Commit Strategy

```elixir
defmodule MyApp.CommitStrategy do
  def adaptive_commit(index, documents, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 1000)
    commit_threshold = Keyword.get(opts, :commit_threshold, 10_000)
    {:ok, writer} = TantivyEx.IndexWriter.new(index)

    {indexed, uncommitted} =
      documents
      |> Enum.reduce({0, 0}, fn doc, {total, uncommitted} ->
        TantivyEx.IndexWriter.add_document(writer, doc)
        new_total = total + 1
        new_uncommitted = uncommitted + 1

        # Commit when threshold reached
        if new_uncommitted >= commit_threshold do
          TantivyEx.IndexWriter.commit(writer)
          {new_total, 0}
        else
          {new_total, new_uncommitted}
        end
      end)

    # Final commit for remaining documents
    if uncommitted > 0 do
      TantivyEx.IndexWriter.commit(writer)
    end

    {:ok, indexed}
  end
end
```

### Stream Processing

For very large datasets that don't fit in memory:

```elixir
defmodule MyApp.StreamIndexer do
  alias TantivyEx.Index

  def index_from_stream(index, stream) do
    {:ok, writer} = TantivyEx.IndexWriter.new(index)

    stream
    |> Stream.map(&transform_document/1)
    |> Stream.chunk_every(500)
    |> Stream.each(&index_batch(writer, &1))
    |> Stream.run()

    TantivyEx.IndexWriter.commit(writer)
  end

  defp transform_document(raw_data) do
    %{
      "title" => raw_data["title"],
      "content" => clean_content(raw_data["body"]),
      "timestamp" => parse_timestamp(raw_data["date"])
    }
  end

  defp index_batch(writer, batch) do
    Enum.each(batch, &TantivyEx.IndexWriter.add_document(writer, &1))
    TantivyEx.IndexWriter.commit(writer)  # Periodic commits
  end
end
```

### Database Integration

Indexing from database records:

```elixir
defmodule MyApp.DBIndexer do
  alias TantivyEx.Index
  import Ecto.Query

  def index_all_articles(index) do
    {:ok, writer} = TantivyEx.IndexWriter.new(index)

    Article
    |> order_by(:id)
    |> MyApp.Repo.stream()
    |> Stream.map(&article_to_document/1)
    |> Stream.chunk_every(1000)
    |> Stream.each(&index_batch(writer, &1))
    |> Stream.run()

    TantivyEx.IndexWriter.commit(writer)
  end

  defp article_to_document(article) do
    %{
      "id" => article.id,
      "title" => article.title,
      "content" => article.content,
      "author" => article.author.name,
      "published_at" => DateTime.to_unix(article.published_at),
      "category" => "/#{article.category}/#{article.subcategory}"
    }
  end

  defp index_batch(writer, batch) do
    Enum.each(batch, &TantivyEx.IndexWriter.add_document(writer, &1))
  end
end
```

## Index Management

### Index Lifecycle Management

```elixir
defmodule MyApp.IndexManager do
  alias TantivyEx.Index

  @index_path "/var/lib/myapp/search_index"

  def create_fresh_index(schema) do
    # Remove existing index if it exists
    if File.exists?(@index_path) do
      File.rm_rf!(@index_path)
    end

    # Create new index
    Index.create_in_dir(@index_path, schema)
  end

  def open_or_create_index(schema) do
    case Index.create_in_dir(@index_path, schema) do
      {:ok, index} ->
        {:ok, index}

      {:error, reason} when reason =~ "already exists" ->
        # Index exists, recreate to ensure schema consistency
        File.rm_rf!(@index_path)
        File.mkdir_p!(@index_path)
        Index.create_in_dir(@index_path, schema)

      {:error, _reason} ->
        IO.puts("Index not found, creating new one...")
        Index.create_in_dir(@index_path, schema)
    end
  end

  def backup_index(backup_path) do
    if File.exists?(@index_path) do
      timestamp = DateTime.utc_now() |> DateTime.to_unix() |> to_string()
      backup_dir = Path.join(backup_path, "index_backup_#{timestamp}")

      case File.cp_r(@index_path, backup_dir) do
        {:ok, _} -> {:ok, backup_dir}
        {:error, reason} -> {:error, "Backup failed: #{reason}"}
      end
    else
      {:error, "No index to backup"}
    end
  end

  def restore_index(backup_path) do
    if File.exists?(backup_path) do
      # Create backup of current index
      current_backup = @index_path <> ".old"
      if File.exists?(@index_path) do
        File.rename(@index_path, current_backup)
      end

      # Restore from backup
      case File.cp_r(backup_path, @index_path) do
        {:ok, _} ->
          # Clean up old backup
          if File.exists?(current_backup) do
            File.rm_rf!(current_backup)
          end
          {:ok, @index_path}

        {:error, reason} ->
          # Restore original if restore failed
          if File.exists?(current_backup) do
            File.rename(current_backup, @index_path)
          end
          {:error, "Restore failed: #{reason}"}
      end
    else
      {:error, "Backup path does not exist"}
    end
  end
end
```

### Index Statistics and Health Checks

```elixir
defmodule MyApp.IndexStats do
  def get_index_info(index_path) do
    case File.stat(index_path) do
      {:ok, stat} ->
        %{
          size_bytes: stat.size,
          size_mb: Float.round(stat.size / (1024 * 1024), 2),
          last_modified: stat.mtime,
          exists: true
        }

      {:error, _} ->
        %{exists: false}
    end
  end

  def health_check(index_path) do
    try do
      # Try to verify index exists by checking for meta files
      if File.exists?(Path.join(index_path, "meta.json")) do
        %{
            status: :healthy,
            message: "Index opened successfully",
            timestamp: DateTime.utc_now()
          }

        {:error, reason} ->
          %{
            status: :unhealthy,
            message: "Failed to open index: #{inspect(reason)}",
            timestamp: DateTime.utc_now()
          }
      end
    rescue
      e ->
        %{
          status: :error,
          message: "Exception during health check: #{inspect(e)}",
          timestamp: DateTime.utc_now()
        }
    end
  end
end
```

## Advanced Indexing Patterns

### Concurrent Indexing with Workers

```elixir
defmodule MyApp.ConcurrentIndexer do
  use GenServer
  alias TantivyEx.Index

  def start_link(index, opts \\ []) do
    GenServer.start_link(__MODULE__, {index, opts}, name: __MODULE__)
  end

  def add_document_async(document) do
    GenServer.cast(__MODULE__, {:add_document, document})
  end

  def flush_and_commit do
    GenServer.call(__MODULE__, :flush_and_commit, 30_000)
  end

  def init({index, opts}) do
    batch_size = Keyword.get(opts, :batch_size, 100)
    flush_interval = Keyword.get(opts, :flush_interval, 5000)

    # Schedule periodic flush
    :timer.send_interval(flush_interval, :flush)

    {:ok, %{
      index: index,
      batch: [],
      batch_size: batch_size,
      total_indexed: 0
    }}
  end

  def handle_cast({:add_document, document}, state) do
    new_batch = [document | state.batch]

    if length(new_batch) >= state.batch_size do
      # Process batch when size reached
      process_batch(state.index, new_batch)
      {:noreply, %{state | batch: [], total_indexed: state.total_indexed + length(new_batch)}}
    else
      {:noreply, %{state | batch: new_batch}}
    end
  end

  def handle_call(:flush_and_commit, _from, state) do
    # Process remaining documents
    if length(state.batch) > 0 do
      process_batch(state.index, state.batch)
    end

    # Commit changes
    {:ok, writer} = TantivyEx.IndexWriter.new(state.index)
    case TantivyEx.IndexWriter.commit(writer) do
      :ok ->
        total = state.total_indexed + length(state.batch)
        {:reply, {:ok, total}, %{state | batch: [], total_indexed: total}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_info(:flush, state) do
    # Periodic flush without commit
    if length(state.batch) > 0 do
      process_batch(state.index, state.batch)
      {:noreply, %{state | batch: [], total_indexed: state.total_indexed + length(state.batch)}}
    else
      {:noreply, state}
    end
  end

  defp process_batch(index, batch) do
    {:ok, writer} = TantivyEx.IndexWriter.new(index)
    Enum.each(batch, &TantivyEx.IndexWriter.add_document(writer, &1))
  end
end
```

### Multi-Index Management

```elixir
defmodule MyApp.MultiIndexManager do
  @moduledoc """
  Manages multiple indexes for different data types or sharding
  """

  defstruct [:indexes, :routing_strategy]

  def new(index_configs, routing_strategy \\ :round_robin) do
    indexes =
      Enum.reduce(index_configs, %{}, fn {name, config}, acc ->
        case create_or_open_index(config) do
          {:ok, index} -> Map.put(acc, name, index)
          {:error, reason} -> raise "Failed to create index #{name}: #{reason}"
        end
      end)

    %__MODULE__{
      indexes: indexes,
      routing_strategy: routing_strategy
    }
  end

  def add_document(manager, document, index_name \\ nil) do
    target_index = select_index(manager, document, index_name)

    case Map.get(manager.indexes, target_index) do
      nil -> {:error, "Index #{target_index} not found"}
      index ->
        {:ok, writer} = TantivyEx.IndexWriter.new(index)
        TantivyEx.IndexWriter.add_document(writer, document)
    end
  end

  def search_all(manager, query, limit) do
    # Search across all indexes and merge results
    results =
      Enum.flat_map(manager.indexes, fn {_name, index} ->
        case TantivyEx.Searcher.new(index) do
          {:ok, searcher} ->
            case TantivyEx.Searcher.search(searcher, query, limit) do
              {:ok, results} -> results
              {:error, _} -> []
            end
          {:error, _} -> []
        end
      end)

    # Simple merging - in production you might want relevance-based merging
    limited_results = Enum.take(results, limit)
    {:ok, limited_results}
  end

  def commit_all(manager) do
    results =
      Enum.map(manager.indexes, fn {name, index} ->
        {:ok, writer} = TantivyEx.IndexWriter.new(index)
        case TantivyEx.IndexWriter.commit(writer) do
          :ok -> {:ok, name}
          {:error, reason} -> {:error, name, reason}
        end
      end)

    errors = Enum.filter(results, &match?({:error, _, _}, &1))

    case errors do
      [] -> {:ok, results}
      _ -> {:error, errors}
    end
  end

  defp select_index(manager, document, nil) do
    case manager.routing_strategy do
      :round_robin ->
        # Simple round-robin selection
        index_names = Map.keys(manager.indexes)
        index_count = length(index_names)
        doc_hash = :erlang.phash2(document)
        index_pos = rem(doc_hash, index_count)
        Enum.at(index_names, index_pos)

      :by_type ->
        # Route by document type
        Map.get(document, "type", :default)

      :by_date ->
        # Route by date (for time-based sharding)
        timestamp = Map.get(document, "timestamp", System.system_time(:second))
        date = DateTime.from_unix!(timestamp) |> DateTime.to_date()
        "index_#{date.year}_#{date.month}"
    end
  end

  defp select_index(_manager, _document, index_name), do: index_name

  defp create_or_open_index(%{path: path, schema: schema}) do
    case TantivyEx.Index.create_in_dir(path, schema) do
      {:ok, index} ->
        {:ok, index}
      {:error, reason} when reason =~ "already exists" ->
        # Index exists, recreate to ensure schema consistency
        File.rm_rf!(path)
        File.mkdir_p!(path)
        TantivyEx.Index.create_in_dir(path, schema)
      {:error, _} = error ->
        error
    end
  end
end
```

## Error Handling & Recovery

### Using Rollback for Error Recovery

```elixir
defmodule MyApp.SafeIndexer do
  require Logger
  alias TantivyEx.IndexWriter

  def safe_batch_index(index, documents) do
    {:ok, writer} = IndexWriter.new(index)

    try do
      # Process each document
      Enum.each(documents, fn document ->
        validate_document!(document)
        IndexWriter.add_document(writer, document)
      end)

      # Commit all changes if everything succeeded
      :ok = IndexWriter.commit(writer)
      {:ok, length(documents)}
    rescue
      e ->
        # Roll back all pending changes on error
        Logger.error("Batch indexing failed: #{inspect(e)}")
        :ok = IndexWriter.rollback(writer)
        {:error, :indexing_failed}
    end
  end

  def safe_delete_by_query(index, query) do
    {:ok, writer} = IndexWriter.new(index)

    case IndexWriter.delete_documents(writer, query) do
      :ok ->
        # Commit the deletion
        case IndexWriter.commit(writer) do
          :ok -> {:ok, :deleted}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to delete documents: #{inspect(reason)}")
        :ok = IndexWriter.rollback(writer)
        {:error, :deletion_failed}
    end
  end
end
```

### Using Transactions Pattern

```elixir
defmodule MyApp.TransactionalIndexer do
  alias TantivyEx.IndexWriter

  def transaction(index, fun) when is_function(fun, 1) do
    {:ok, writer} = IndexWriter.new(index)

    try do
      # Execute the transaction function with the writer
      case fun.(writer) do
        {:ok, result} ->
          # On success, commit the changes
          :ok = IndexWriter.commit(writer)
          {:ok, result}

        {:error, reason} ->
          # On error, roll back the changes
          :ok = IndexWriter.rollback(writer)
          {:error, reason}
      end
    rescue
      e ->
        # On exception, roll back the changes
        :ok = IndexWriter.rollback(writer)
        {:error, {:exception, e}}
    end
  end
end

# Usage example
MyApp.TransactionalIndexer.transaction(index, fn writer ->
  :ok = IndexWriter.add_document(writer, doc1)
  :ok = IndexWriter.add_document(writer, doc2)

  if valid_operation? do
    {:ok, :success}
  else
    {:error, :validation_failed}
  end
end)
```

### Robust Error Handling

```elixir
defmodule MyApp.RobustIndexer do
  require Logger

  def index_with_retry(index, document, max_retries \\ 3) do
    do_index_with_retry(index, document, max_retries, 0)
  end

  defp do_index_with_retry(index, document, max_retries, attempt) do
    {:ok, writer} = TantivyEx.IndexWriter.new(index)
    case TantivyEx.IndexWriter.add_document(writer, document) do
      :ok ->
        {:ok, :success}

      {:error, reason} when attempt < max_retries ->
        Logger.warn("Indexing failed (attempt #{attempt + 1}/#{max_retries + 1}): #{inspect(reason)}")

        # Exponential backoff
        sleep_time = :math.pow(2, attempt) * 100 |> trunc()
        Process.sleep(sleep_time)

        do_index_with_retry(index, document, max_retries, attempt + 1)

      {:error, reason} ->
        Logger.error("Indexing failed after #{max_retries + 1} attempts: #{inspect(reason)}")
        {:error, {:max_retries_exceeded, reason}}
    end
  end

  def batch_index_with_recovery(index, documents) do
    {successful, failed} =
      Enum.reduce(documents, {[], []}, fn doc, {success, failures} ->
        case index_with_retry(index, doc) do
          {:ok, _} -> {[doc | success], failures}
          {:error, reason} -> {success, [{doc, reason} | failures]}
        end
      end)

    # Log results
    Logger.info("Batch indexing complete: #{length(successful)} successful, #{length(failed)} failed")

    if length(failed) > 0 do
      Logger.error("Failed documents: #{inspect(failed)}")
    end

    # Commit successful documents
    {:ok, writer} = TantivyEx.IndexWriter.new(index)
    case TantivyEx.IndexWriter.commit(writer) do
      :ok ->
        {:ok, %{successful: length(successful), failed: failed}}

      {:error, reason} ->
        Logger.error("Commit failed: #{inspect(reason)}")
        {:error, {:commit_failed, reason}}
    end
  end
end
```

## Production Best Practices

### Production-Ready Indexing Service

```elixir
defmodule MyApp.IndexingService do
  use GenServer
  require Logger

  alias TantivyEx.Index
  alias MyApp.{DocumentConverter, IndexManager, DeadLetterQueue}

  @default_batch_size 500
  @default_commit_interval 5_000
  @health_check_interval 30_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API
  def index_document(document) do
    GenServer.cast(__MODULE__, {:index_document, document})
  end

  def index_documents(documents) when is_list(documents) do
    GenServer.cast(__MODULE__, {:index_documents, documents})
  end

  def force_commit do
    GenServer.call(__MODULE__, :force_commit, 30_000)
  end

  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  def health_check do
    GenServer.call(__MODULE__, :health_check)
  end

  # GenServer Implementation
  def init(opts) do
    schema = Keyword.fetch!(opts, :schema)
    index_path = Keyword.get(opts, :index_path, "/var/lib/myapp/search_index")

    case IndexManager.open_or_create_index(schema) do
      {:ok, index} ->
        # Schedule periodic operations
        schedule_commit()
        schedule_health_check()

        {:ok, %{
          index: index,
          schema: schema,
          index_path: index_path,
          pending_documents: [],
          batch_size: Keyword.get(opts, :batch_size, @default_batch_size),
          commit_interval: Keyword.get(opts, :commit_interval, @default_commit_interval),
          stats: init_stats(),
          last_commit: DateTime.utc_now(),
          healthy: true
        }}

      {:error, reason} ->
        Logger.error("Failed to initialize index: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  def handle_cast({:index_document, document}, state) do
    converted_doc = DocumentConverter.prepare_for_indexing(document)
    new_pending = [converted_doc | state.pending_documents]

    if length(new_pending) >= state.batch_size do
      case process_batch(state.index, new_pending) do
        {:ok, processed} ->
          stats = update_stats(state.stats, :documents_indexed, processed)
          {:noreply, %{state | pending_documents: [], stats: stats}}

        {:error, reason} ->
          Logger.error("Batch processing failed: #{inspect(reason)}")
          # Add to dead letter queue
          Enum.each(new_pending, &DeadLetterQueue.add_failed_document(&1, reason))
          {:noreply, %{state | pending_documents: []}}
      end
    else
      {:noreply, %{state | pending_documents: new_pending}}
    end
  end

  def handle_cast({:index_documents, documents}, state) do
    converted_docs = Enum.map(documents, &DocumentConverter.prepare_for_indexing/1)

    case process_batch(state.index, converted_docs) do
      {:ok, processed} ->
        stats = update_stats(state.stats, :documents_indexed, processed)
        {:noreply, %{state | stats: stats}}

      {:error, reason} ->
        Logger.error("Batch processing failed: #{inspect(reason)}")
        Enum.each(converted_docs, &DeadLetterQueue.add_failed_document(&1, reason))
        {:noreply, state}
    end
  end

  def handle_call(:force_commit, _from, state) do
    # Process pending documents first
    if length(state.pending_documents) > 0 do
      process_batch(state.index, state.pending_documents)
    end

    {:ok, writer} = TantivyEx.IndexWriter.new(state.index)
    case TantivyEx.IndexWriter.commit(writer) do
      :ok ->
        stats = update_stats(state.stats, :commits, 1)
        {:reply, :ok, %{state |
          pending_documents: [],
          stats: stats,
          last_commit: DateTime.utc_now()
        }}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  def handle_call(:health_check, _from, state) do
    health_status = %{
      healthy: state.healthy,
      pending_documents: length(state.pending_documents),
      last_commit: state.last_commit,
      uptime: DateTime.diff(DateTime.utc_now(), state.stats.started_at),
      stats: state.stats
    }

    {:reply, health_status, state}
  end

  def handle_info(:commit, state) do
    if length(state.pending_documents) > 0 do
      case process_batch(state.index, state.pending_documents) do
        {:ok, _} ->
          {:ok, writer} = TantivyEx.IndexWriter.new(state.index)
          case TantivyEx.IndexWriter.commit(writer) do
            :ok ->
              stats = update_stats(state.stats, :commits, 1)
              schedule_commit()
              {:noreply, %{state |
                pending_documents: [],
                stats: stats,
                last_commit: DateTime.utc_now()
              }}

            {:error, reason} ->
              Logger.error("Commit failed: #{inspect(reason)}")
              schedule_commit()
              {:noreply, state}
          end

        {:error, reason} ->
          Logger.error("Batch processing failed during commit: #{inspect(reason)}")
          schedule_commit()
          {:noreply, state}
      end
    else
      schedule_commit()
      {:noreply, state}
    end
  end

  def handle_info(:health_check, state) do
    healthy = perform_health_check(state.index)
    schedule_health_check()
    {:noreply, %{state | healthy: healthy}}
  end

  # Private functions
  defp process_batch(index, documents) do
    start_time = System.monotonic_time(:millisecond)
    {:ok, writer} = TantivyEx.IndexWriter.new(index)

    result = Enum.reduce_while(documents, {:ok, 0}, fn doc, {:ok, count} ->
      case TantivyEx.IndexWriter.add_document(writer, doc) do
        :ok -> {:cont, {:ok, count + 1}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)

    case result do
      {:ok, processed} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time
        Logger.debug("Processed #{processed} documents in #{duration}ms")
        {:ok, processed}

      error -> error
    end
  end

  defp init_stats do
    %{
      documents_indexed: 0,
      commits: 0,
      errors: 0,
      started_at: DateTime.utc_now()
    }
  end

  defp update_stats(stats, key, increment) do
    Map.update!(stats, key, &(&1 + increment))
  end

  defp schedule_commit do
    Process.send_after(self(), :commit, @default_commit_interval)
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @health_check_interval)
  end

  defp perform_health_check(index) do
    # Simple health check - try to search
    case TantivyEx.Searcher.new(index) do
      {:ok, searcher} ->
        case TantivyEx.Searcher.search(searcher, "*", 1) do
          {:ok, _} -> true
          {:error, _} -> false
        end
      {:error, _} -> false
    end
  end
end
```

This comprehensive indexing guide provides everything you need to efficiently index documents with TantivyEx, from basic operations to production-ready patterns with error handling, monitoring, and recovery mechanisms.
