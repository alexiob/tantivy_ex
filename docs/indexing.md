# Indexing Guide

This guide covers document indexing strategies, batch operations, and performance optimization in TantivyEx.

## Table of Contents

- [Basic Indexing](#basic-indexing)
- [Batch Operations](#batch-operations)
- [Index Management](#index-management)
- [Performance Optimization](#performance-optimization)
- [Error Handling](#error-handling)
- [Real-world Examples](#real-world-examples)

## Basic Indexing

### Creating an Index

```elixir
alias TantivyEx.{Index, Schema}

# Create schema first
{:ok, schema} = Schema.new()
{:ok, schema} = Schema.add_text_field(schema, "title", :TEXT_STORED)
{:ok, schema} = Schema.add_text_field(schema, "content", :TEXT)
{:ok, schema} = Schema.add_u64_field(schema, "timestamp", :INDEXED)

# Create index with schema
index_path = "/path/to/index"
{:ok, index} = Index.create(index_path, schema)
```

### Adding Documents

```elixir
# Single document
document = %{
  "title" => "Introduction to Elixir",
  "content" => "Elixir is a dynamic, functional language...",
  "timestamp" => System.system_time(:second)
}

{:ok, _} = Index.add_document(index, document)

# Commit changes to make them searchable
{:ok, _} = Index.commit(index)
```

### Document Structure Requirements

Documents must match the schema field types:

```elixir
# Text fields: strings
"title" => "My Article"

# Numeric fields: integers or floats
"timestamp" => 1640995200
"price" => 29.99

# Date fields: Unix timestamps (seconds since epoch)
"created_at" => System.system_time(:second)

# JSON fields: maps or serialized JSON
"metadata" => %{"author" => "John", "tags" => ["elixir", "programming"]}

# Facet fields: hierarchical paths
"category" => "/books/programming/elixir"

# IP address fields: string representation
"client_ip" => "192.168.1.1"

# Binary fields: binary data
"file_content" => File.read!("document.pdf")
```

## Batch Operations

### Efficient Bulk Indexing

For large datasets, batch processing is essential for performance:

```elixir
defmodule MyApp.BulkIndexer do
  alias TantivyEx.Index

  @batch_size 1000

  def index_documents(index, documents) do
    documents
    |> Enum.chunk_every(@batch_size)
    |> Enum.each(&index_batch(index, &1))

    # Final commit
    Index.commit(index)
  end

  defp index_batch(index, batch) do
    Enum.each(batch, fn doc ->
      case Index.add_document(index, doc) do
        {:ok, _} -> :ok
        {:error, reason} ->
          Logger.error("Failed to index document: #{inspect(reason)}")
      end
    end)

    # Periodic commits for large batches
    Index.commit(index)
  end
end
```

### Stream Processing

For very large datasets that don't fit in memory:

```elixir
defmodule MyApp.StreamIndexer do
  alias TantivyEx.Index

  def index_from_stream(index, stream) do
    stream
    |> Stream.map(&transform_document/1)
    |> Stream.chunk_every(500)
    |> Stream.each(&index_batch(index, &1))
    |> Stream.run()

    Index.commit(index)
  end

  defp transform_document(raw_data) do
    %{
      "title" => raw_data["title"],
      "content" => clean_content(raw_data["body"]),
      "timestamp" => parse_timestamp(raw_data["date"])
    }
  end

  defp index_batch(index, batch) do
    Enum.each(batch, &Index.add_document(index, &1))
    Index.commit(index)  # Periodic commits
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
    Article
    |> order_by(:id)
    |> MyApp.Repo.stream()
    |> Stream.map(&article_to_document/1)
    |> Stream.chunk_every(1000)
    |> Stream.each(&index_batch(index, &1))
    |> Stream.run()

    Index.commit(index)
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

  defp index_batch(index, batch) do
    Enum.each(batch, &Index.add_document(index, &1))
  end
end
```

## Index Management

### Opening Existing Indexes

```elixir
# Open existing index
{:ok, index} = Index.open("/path/to/existing/index")

# Verify index is healthy
case Index.commit(index) do
  {:ok, _} -> Logger.info("Index opened successfully")
  {:error, reason} -> Logger.error("Index corrupted: #{inspect(reason)}")
end
```

### Index Statistics

Monitor index health and size:

```elixir
defmodule MyApp.IndexMonitor do
  alias TantivyEx.Index

  def get_index_stats(index_path) do
    case File.stat(index_path) do
      {:ok, %{size: size}} ->
        %{
          size_mb: size / (1024 * 1024),
          path: index_path,
          last_modified: File.stat!(index_path).mtime
        }
      {:error, _} ->
        %{error: "Index not found"}
    end
  end

  def monitor_index_performance(index, sample_queries) do
    Enum.map(sample_queries, fn query ->
      {time, result} = :timer.tc(fn ->
        Index.search(index, query, 10)
      end)

      %{
        query: query,
        time_ms: time / 1000,
        result_count: length(elem(result, 1))
      }
    end)
  end
end
```

### Index Maintenance

```elixir
defmodule MyApp.IndexMaintenance do
  alias TantivyEx.Index

  def optimize_index(index) do
    # Force merge segments for better performance
    case Index.commit(index) do
      {:ok, _} -> Logger.info("Index optimized successfully")
      {:error, reason} -> Logger.error("Optimization failed: #{inspect(reason)}")
    end
  end

  def backup_index(source_path, backup_path) do
    case File.cp_r(source_path, backup_path) do
      {:ok, _} ->
        Logger.info("Index backed up to #{backup_path}")
        {:ok, backup_path}
      {:error, reason} ->
        Logger.error("Backup failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
```

## Performance Optimization

### Commit Strategies

Balance between write performance and search freshness:

```elixir
defmodule MyApp.CommitStrategies do
  alias TantivyEx.Index

  # Strategy 1: Frequent commits (real-time search)
  def realtime_indexing(index, documents) do
    Enum.each(documents, fn doc ->
      Index.add_document(index, doc)
      Index.commit(index)  # Immediate visibility
    end)
  end

  # Strategy 2: Batch commits (better throughput)
  def batch_indexing(index, documents) do
    Enum.each(documents, &Index.add_document(index, &1))
    Index.commit(index)  # Single commit at end
  end

  # Strategy 3: Timed commits (balanced approach)
  def timed_indexing(index, documents, commit_interval_ms \\ 5000) do
    start_time = System.monotonic_time(:millisecond)

    Enum.reduce(documents, start_time, fn doc, last_commit ->
      Index.add_document(index, doc)

      current_time = System.monotonic_time(:millisecond)
      if current_time - last_commit >= commit_interval_ms do
        Index.commit(index)
        current_time
      else
        last_commit
      end
    end)

    Index.commit(index)  # Final commit
  end
end
```

### Memory Management

```elixir
defmodule MyApp.MemoryOptimizer do
  alias TantivyEx.Index

  @doc """
  Process large datasets with memory constraints
  """
  def memory_efficient_indexing(index, data_source, max_memory_mb \\ 100) do
    chunk_size = calculate_chunk_size(max_memory_mb)

    data_source
    |> Stream.chunk_every(chunk_size)
    |> Stream.each(fn chunk ->
      # Process chunk
      Enum.each(chunk, &Index.add_document(index, &1))
      Index.commit(index)

      # Force garbage collection
      :erlang.garbage_collect()
    end)
    |> Stream.run()
  end

  defp calculate_chunk_size(max_memory_mb) do
    # Estimate based on average document size
    avg_doc_size_kb = 10  # Adjust based on your data
    max_memory_kb = max_memory_mb * 1024
    max(1, div(max_memory_kb, avg_doc_size_kb))
  end
end
```

### Parallel Indexing

```elixir
defmodule MyApp.ParallelIndexer do
  alias TantivyEx.Index

  def parallel_index(documents, index_path, schema, num_workers \\ 4) do
    # Split documents across workers
    documents
    |> Enum.chunk_every(div(length(documents), num_workers))
    |> Task.async_stream(
      &index_worker(&1, index_path, schema),
      max_concurrency: num_workers,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, result} -> result end)

    # Final merge step (if needed)
    {:ok, final_index} = Index.open(index_path)
    Index.commit(final_index)
  end

  defp index_worker(documents, index_path, schema) do
    worker_index_path = "#{index_path}_worker_#{:rand.uniform(10000)}"
    {:ok, index} = Index.create(worker_index_path, schema)

    Enum.each(documents, &Index.add_document(index, &1))
    Index.commit(index)

    worker_index_path
  end
end
```

## Error Handling

### Robust Document Processing

```elixir
defmodule MyApp.RobustIndexer do
  alias TantivyEx.Index
  require Logger

  def safe_index_documents(index, documents) do
    {success_count, error_count} =
      Enum.reduce(documents, {0, 0}, fn doc, {success, errors} ->
        case safe_add_document(index, doc) do
          :ok -> {success + 1, errors}
          :error -> {success, errors + 1}
        end
      end)

    case Index.commit(index) do
      {:ok, _} ->
        Logger.info("Indexed #{success_count} documents, #{error_count} errors")
        {:ok, {success_count, error_count}}
      {:error, reason} ->
        Logger.error("Commit failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp safe_add_document(index, document) do
    case validate_document(document) do
      :ok ->
        case Index.add_document(index, document) do
          {:ok, _} -> :ok
          {:error, reason} ->
            Logger.warn("Failed to index document: #{inspect(reason)}")
            :error
        end
      {:error, reason} ->
        Logger.warn("Invalid document: #{inspect(reason)}")
        :error
    end
  end

  defp validate_document(doc) when is_map(doc) do
    required_fields = ["title", "content"]

    case Enum.all?(required_fields, &Map.has_key?(doc, &1)) do
      true -> :ok
      false -> {:error, "Missing required fields"}
    end
  end
  defp validate_document(_), do: {:error, "Document must be a map"}
end
```

### Retry Logic

```elixir
defmodule MyApp.RetryIndexer do
  alias TantivyEx.Index

  def index_with_retry(index, document, max_retries \\ 3) do
    do_index_with_retry(index, document, max_retries, 0)
  end

  defp do_index_with_retry(index, document, max_retries, attempt) do
    case Index.add_document(index, document) do
      {:ok, result} -> {:ok, result}
      {:error, reason} when attempt < max_retries ->
        Logger.warn("Index attempt #{attempt + 1} failed: #{inspect(reason)}")
        :timer.sleep(1000 * attempt)  # Exponential backoff
        do_index_with_retry(index, document, max_retries, attempt + 1)
      {:error, reason} ->
        Logger.error("Index failed after #{max_retries} attempts: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
```

## Real-world Examples

### E-commerce Product Indexing

```elixir
defmodule MyApp.ProductIndexer do
  alias TantivyEx.{Index, Schema}

  def create_product_index(index_path) do
    {:ok, schema} = Schema.new()
    {:ok, schema} = Schema.add_text_field(schema, "name", :TEXT_STORED)
    {:ok, schema} = Schema.add_text_field(schema, "description", :TEXT)
    {:ok, schema} = Schema.add_text_field(schema, "brand", :TEXT_STORED)
    {:ok, schema} = Schema.add_facet_field(schema, "category", :INDEXED)
    {:ok, schema} = Schema.add_f64_field(schema, "price", :INDEXED)
    {:ok, schema} = Schema.add_u64_field(schema, "stock", :INDEXED)
    {:ok, schema} = Schema.add_f64_field(schema, "rating", :INDEXED)
    {:ok, schema} = Schema.add_json_field(schema, "attributes", :STORED)

    Index.create(index_path, schema)
  end

  def index_products_from_catalog(index, catalog_file) do
    catalog_file
    |> File.stream!()
    |> Stream.map(&Jason.decode!/1)
    |> Stream.map(&transform_product/1)
    |> Stream.chunk_every(500)
    |> Stream.each(&index_batch(index, &1))
    |> Stream.run()

    Index.commit(index)
  end

  defp transform_product(product) do
    %{
      "name" => product["name"],
      "description" => clean_html(product["description"]),
      "brand" => product["brand"],
      "category" => build_category_path(product["categories"]),
      "price" => parse_price(product["price"]),
      "stock" => product["inventory"]["quantity"],
      "rating" => calculate_average_rating(product["reviews"]),
      "attributes" => extract_attributes(product)
    }
  end

  defp clean_html(html) do
    html
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp build_category_path(categories) do
    "/" <> Enum.join(categories, "/")
  end

  defp index_batch(index, products) do
    Enum.each(products, &Index.add_document(index, &1))
  end
end
```

### Blog Content Indexing

```elixir
defmodule MyApp.BlogIndexer do
  alias TantivyEx.{Index, Schema}
  alias MyApp.Repo

  def create_blog_index(index_path) do
    {:ok, schema} = Schema.new()
    {:ok, schema} = Schema.add_text_field(schema, "title", :TEXT_STORED)
    {:ok, schema} = Schema.add_text_field(schema, "content", :TEXT)
    {:ok, schema} = Schema.add_text_field(schema, "excerpt", :TEXT_STORED)
    {:ok, schema} = Schema.add_text_field(schema, "author", :TEXT_STORED)
    {:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "tags", :TEXT, "whitespace")
    {:ok, schema} = Schema.add_facet_field(schema, "category", :INDEXED)
    {:ok, schema} = Schema.add_date_field(schema, "published_at", :INDEXED)
    {:ok, schema} = Schema.add_u64_field(schema, "view_count", :INDEXED)

    Index.create(index_path, schema)
  end

  def index_all_posts(index) do
    MyApp.Post
    |> where([p], p.status == "published")
    |> preload([:author, :tags, :category])
    |> Repo.stream()
    |> Stream.map(&post_to_document/1)
    |> Stream.chunk_every(100)
    |> Stream.each(&index_batch(index, &1))
    |> Stream.run()

    Index.commit(index)
  end

  defp post_to_document(post) do
    %{
      "title" => post.title,
      "content" => strip_markdown(post.content),
      "excerpt" => post.excerpt,
      "author" => post.author.name,
      "tags" => Enum.map_join(post.tags, " ", & &1.name),
      "category" => "/#{post.category.slug}",
      "published_at" => DateTime.to_unix(post.published_at),
      "view_count" => post.view_count || 0
    }
  end

  defp strip_markdown(content) do
    content
    |> String.replace(~r/[#*_`\[\]()!]/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp index_batch(index, posts) do
    Enum.each(posts, &Index.add_document(index, &1))
  end
end
```

### Log Analysis Indexing

```elixir
defmodule MyApp.LogIndexer do
  alias TantivyEx.{Index, Schema}

  def create_log_index(index_path) do
    {:ok, schema} = Schema.new()
    {:ok, schema} = Schema.add_text_field(schema, "message", :TEXT)
    {:ok, schema} = Schema.add_text_field(schema, "level", :INDEXED)
    {:ok, schema} = Schema.add_text_field(schema, "service", :INDEXED)
    {:ok, schema} = Schema.add_ip_addr_field(schema, "client_ip", :INDEXED)
    {:ok, schema} = Schema.add_date_field(schema, "timestamp", :INDEXED)
    {:ok, schema} = Schema.add_u64_field(schema, "request_id", :INDEXED)
    {:ok, schema} = Schema.add_json_field(schema, "metadata", :STORED)

    Index.create(index_path, schema)
  end

  def index_log_files(index, log_directory) do
    log_directory
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".log"))
    |> Enum.each(&index_log_file(index, Path.join(log_directory, &1)))

    Index.commit(index)
  end

  defp index_log_file(index, log_file) do
    log_file
    |> File.stream!()
    |> Stream.map(&parse_log_line/1)
    |> Stream.reject(&is_nil/1)
    |> Stream.chunk_every(1000)
    |> Stream.each(&index_batch(index, &1))
    |> Stream.run()
  end

  defp parse_log_line(line) do
    case Jason.decode(String.trim(line)) do
      {:ok, log_entry} ->
        %{
          "message" => log_entry["message"],
          "level" => log_entry["level"],
          "service" => log_entry["service"],
          "client_ip" => log_entry["client_ip"] || "unknown",
          "timestamp" => parse_timestamp(log_entry["timestamp"]),
          "request_id" => log_entry["request_id"] || 0,
          "metadata" => log_entry["metadata"] || %{}
        }
      {:error, _} -> nil
    end
  end

  defp parse_timestamp(timestamp_str) do
    case DateTime.from_iso8601(timestamp_str) do
      {:ok, dt, _} -> DateTime.to_unix(dt)
      {:error, _} -> System.system_time(:second)
    end
  end

  defp index_batch(index, logs) do
    Enum.each(logs, &Index.add_document(index, &1))
  end
end
```

## Performance Monitoring

### Indexing Metrics

```elixir
defmodule MyApp.IndexingMetrics do
  def measure_indexing_performance(indexer_func, documents) do
    start_time = System.monotonic_time(:millisecond)
    start_memory = :erlang.memory(:total)

    result = indexer_func.(documents)

    end_time = System.monotonic_time(:millisecond)
    end_memory = :erlang.memory(:total)

    %{
      result: result,
      duration_ms: end_time - start_time,
      memory_used_mb: (end_memory - start_memory) / (1024 * 1024),
      docs_per_second: length(documents) / ((end_time - start_time) / 1000),
      documents_processed: length(documents)
    }
  end
end

# Usage example:
metrics = MyApp.IndexingMetrics.measure_indexing_performance(
  fn docs -> MyApp.BulkIndexer.index_documents(index, docs) end,
  documents
)

IO.inspect(metrics)
# Output: %{
#   result: :ok,
#   duration_ms: 1250,
#   memory_used_mb: 45.2,
#   docs_per_second: 800.0,
#   documents_processed: 1000
# }
```

## Best Practices Summary

1. **Batch operations**: Always process documents in batches for better performance
2. **Commit strategy**: Balance between real-time search and write performance
3. **Error handling**: Implement robust error handling and retry logic
4. **Memory management**: Monitor and control memory usage for large datasets
5. **Document validation**: Validate documents before indexing to prevent errors
6. **Monitoring**: Track indexing performance and index health
7. **Schema planning**: Design schemas to support your indexing patterns
8. **Parallel processing**: Use multiple workers for very large datasets (with caution)
9. **Regular maintenance**: Perform periodic index optimization and cleanup
10. **Testing**: Test indexing performance with realistic data volumes
