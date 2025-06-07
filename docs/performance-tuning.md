# Performance Tuning

Optimizing TantivyEx for production requires understanding how indexing, searching, and memory usage affect performance.

## Index Design for Performance

### Choose the Right Field Options

Different field options have different performance characteristics:

```elixir
# For fields you only search (no retrieval needed)
Schema.add_text_field(schema, "content", :text)

# For fields you search and retrieve
Schema.add_text_field(schema, "title", :text_stored)

# For fast filtering and aggregation
Schema.add_u64_field(schema, "timestamp", :fast)

# For both retrieval and fast operations
Schema.add_f64_field(schema, "price", :fast_stored)
```

**Performance Guidelines:**

- Use `:text` for content you only search, not retrieve
- Use `:fast` for fields used in range queries or sorting
- Use `_stored` variants only when you need to retrieve the original value
- Avoid storing large text fields if you don't need them in results

### Optimize Your Schema

```elixir
# ❌ Poor performance - storing large content unnecessarily
{:ok, schema} = Schema.add_text_field(schema, "full_content", :text_stored)

# ✅ Better - only index for search
{:ok, schema} = Schema.add_text_field(schema, "full_content", :text)

# Store a separate summary field for display
{:ok, schema} = Schema.add_text_field(schema, "summary", :text_stored)
```

### Field Type Selection Impact

```elixir
defmodule SchemaOptimizer do
  def create_optimized_schema() do
    {:ok, schema} = Schema.new()

    # Text fields - choose based on use case
    {:ok, schema} = Schema.add_text_field(schema, "title", :text_stored)     # Search + display
    {:ok, schema} = Schema.add_text_field(schema, "content", :text)          # Search only
    {:ok, schema} = Schema.add_text_field(schema, "summary", :stored)        # Display only

    # Numeric fields - optimize for operations
    {:ok, schema} = Schema.add_u64_field(schema, "timestamp", :fast)         # Filtering/sorting
    {:ok, schema} = Schema.add_f64_field(schema, "price", :fast_stored)      # Filter + display
    {:ok, schema} = Schema.add_u64_field(schema, "view_count", :stored)      # Display only

    # Facet fields - for navigation
    {:ok, schema} = Schema.add_facet_field(schema, "category", :facet)

    {:ok, schema}
  end
end
```

## Indexing Performance

### Batch Operations

Always prefer batch operations over individual document additions:

```elixir
# ❌ Slow - individual commits
{:ok, writer} = TantivyEx.IndexWriter.new(index)
Enum.each(documents, fn doc ->
  TantivyEx.IndexWriter.add_document(writer, doc)
  TantivyEx.IndexWriter.commit(writer)  # Don't do this!
end)

# ✅ Fast - batch commit
{:ok, writer} = TantivyEx.IndexWriter.new(index)
Enum.each(documents, fn doc ->
  TantivyEx.IndexWriter.add_document(writer, doc)
end)
TantivyEx.IndexWriter.commit(writer)  # Single commit at the end
```

### Optimize Commit Frequency

```elixir
defmodule BulkIndexer do
  @batch_size 1000
  @commit_interval_ms 5000

  def index_documents(index, documents) do
    {:ok, writer} = TantivyEx.IndexWriter.new(index)

    documents
    |> Enum.chunk_every(@batch_size)
    |> Enum.each(fn batch ->
      add_batch(writer, batch)
      TantivyEx.IndexWriter.commit(writer)

      # Optional: brief pause to prevent overwhelming the system
      Process.sleep(100)
    end)
  end

  defp add_batch(writer, documents) do
    Enum.each(documents, fn doc ->
      case TantivyEx.IndexWriter.add_document(writer, doc) do
        :ok -> :ok
        {:error, reason} ->
          Logger.warning("Failed to add document: #{inspect(reason)}")
      end
    end)
  end
end
```

### Parallel Indexing

```elixir
defmodule ParallelIndexer do
  def index_documents_parallel(index, documents, num_workers \\ 4) do
    documents
    |> Enum.chunk_every(div(length(documents), num_workers))
    |> Task.async_stream(fn chunk ->
      {:ok, writer} = TantivyEx.IndexWriter.new(index)

      Enum.each(chunk, fn doc ->
        TantivyEx.IndexWriter.add_document(writer, doc)
      end)

      TantivyEx.IndexWriter.commit(writer)
    end, timeout: 60_000)
    |> Enum.to_list()
  end
end
```

## Search Performance

### Query Optimization

```elixir
# ❌ Slow - overly broad queries
{:ok, searcher} = TantivyEx.Searcher.new(index)
TantivyEx.Searcher.search(searcher, "*", 10000)

# ✅ Fast - specific queries with reasonable limits
TantivyEx.Searcher.search(searcher, "specific terms", 50)

# ❌ Slow - complex boolean queries without field targeting
TantivyEx.Searcher.search(searcher, "(a OR b OR c) AND (d OR e OR f)", 100)

# ✅ Fast - field-specific queries
TantivyEx.Searcher.search(searcher, "title:(important terms) AND category:specific", 100)
```

### Result Limiting and Pagination

```elixir
defmodule SearchOptimizer do
  # Don't retrieve more results than you need
  def search_with_limit(index, query, limit \\ 20) do
    {:ok, searcher} = TantivyEx.Searcher.new(index)
    TantivyEx.Searcher.search(searcher, query, limit)
  end

  # Efficient pagination for moderate depths
  def paginated_search(index, query, page, per_page) when page <= 100 do
    limit = page * per_page
    {:ok, searcher} = TantivyEx.Searcher.new(index)

    case TantivyEx.Searcher.search(searcher, query, limit) do
      {:ok, all_results} ->
        start_index = (page - 1) * per_page
        page_results = Enum.slice(all_results, start_index, per_page)
        {:ok, page_results}

      error -> error
    end
  end

  # For deep pagination, consider cursor-based approaches
  def cursor_based_search(index, query, cursor, per_page) do
    # Implementation depends on your specific use case
    # Consider using a timestamp or ID field for cursor
    enhanced_query = "#{query} AND timestamp:>#{cursor}"
    search_with_limit(index, enhanced_query, per_page)
  end
end
```

### Query Caching

```elixir
defmodule QueryCache do
  use GenServer

  # Simple in-memory cache for frequent queries
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def search_cached(index, query, limit) do
    cache_key = {query, limit}

    case GenServer.call(__MODULE__, {:get, cache_key}) do
      nil ->
        {:ok, results} = search_and_cache(index, query, limit, cache_key)
        results

      cached_results ->
        cached_results
    end
  end

  defp search_and_cache(index, query, limit, cache_key) do
    {:ok, searcher} = TantivyEx.Searcher.new(index)

    case TantivyEx.Searcher.search(searcher, query, limit) do
      {:ok, results} = success ->
        GenServer.cast(__MODULE__, {:put, cache_key, results})
        success

      error -> error
    end
  end

  # GenServer callbacks
  def init(state), do: {:ok, state}

  def handle_call({:get, key}, _from, cache) do
    {:reply, Map.get(cache, key), cache}
  end

  def handle_cast({:put, key, value}, cache) do
    # Simple cache with size limit
    new_cache =
      cache
      |> Map.put(key, value)
      |> maybe_evict_old_entries()

    {:noreply, new_cache}
  end

  defp maybe_evict_old_entries(cache) when map_size(cache) > 1000 do
    # Keep only the most recent 500 entries
    cache
    |> Enum.take(500)
    |> Map.new()
  end

  defp maybe_evict_old_entries(cache), do: cache
end
```

## Memory Management

### Index Size Monitoring

```elixir
defmodule IndexMonitor do
  require Logger

  def check_index_stats(index_path) do
    case File.stat(index_path) do
      {:ok, %{size: size}} ->
        size_mb = size / (1024 * 1024)
        Logger.info("Index size: #{Float.round(size_mb, 2)} MB")
        {:ok, size_mb}

      {:error, reason} ->
        Logger.error("Could not get index stats: #{reason}")
        {:error, reason}
    end
  end

  def monitor_index_growth(index_path, threshold_mb \\ 1000) do
    case check_index_stats(index_path) do
      {:ok, size_mb} when size_mb > threshold_mb ->
        Logger.warning("Index size (#{size_mb} MB) exceeds threshold (#{threshold_mb} MB)")
        :threshold_exceeded

      {:ok, _size_mb} ->
        :ok

      error -> error
    end
  end
end
```

### RAM vs Disk Indexes

```elixir
defmodule IndexStrategy do
  def choose_index_type(dataset_size_mb, available_ram_mb) do
    cond do
      dataset_size_mb < 100 and available_ram_mb > 1000 ->
        {:ram_index, "Small dataset, use RAM for speed"}

      dataset_size_mb < available_ram_mb * 0.5 ->
        {:ram_index, "Dataset fits comfortably in RAM"}

      true ->
        {:disk_index, "Dataset too large for RAM or limited memory"}
    end
  end

  def create_optimized_index(schema, strategy, path \\ nil) do
    case strategy do
      {:ram_index, _reason} ->
        Index.create_in_ram(schema)

      {:disk_index, _reason} ->
        path = path || generate_temp_path()
        Index.create_in_dir(path, schema)
    end
  end

  defp generate_temp_path do
    timestamp = System.system_time(:second)
    "/tmp/tantivy_index_#{timestamp}"
  end
end
```

## Performance Benchmarking

```elixir
defmodule PerformanceBenchmark do
  def benchmark_indexing(documents, batch_sizes \\ [100, 500, 1000, 5000]) do
    schema = create_test_schema()

    Enum.map(batch_sizes, fn batch_size ->
      {time, _result} = :timer.tc(fn ->
        index_with_batch_size(documents, schema, batch_size)
      end)

      time_ms = time / 1000
      docs_per_second = length(documents) / (time_ms / 1000)

      %{
        batch_size: batch_size,
        time_ms: time_ms,
        docs_per_second: Float.round(docs_per_second, 2)
      }
    end)
  end

  def benchmark_queries(index, queries) do
    {:ok, searcher} = TantivyEx.Searcher.new(index)

    Enum.map(queries, fn query ->
      {time, result} = :timer.tc(fn ->
        TantivyEx.Searcher.search(searcher, query, 100)
      end)

      time_ms = time / 1000
      result_count = case result do
        {:ok, results} -> length(results)
        _ -> 0
      end

      %{
        query: query,
        time_ms: time_ms,
        result_count: result_count
      }
    end)
  end

  defp create_test_schema do
    {:ok, schema} = Schema.new()
    {:ok, schema} = Schema.add_text_field(schema, "title", :text_stored)
    {:ok, schema} = Schema.add_text_field(schema, "content", :text)
    {:ok, schema} = Schema.add_u64_field(schema, "timestamp", :fast)
    schema
  end

  defp index_with_batch_size(documents, schema, batch_size) do
    {:ok, index} = Index.create_in_ram(schema)
    {:ok, writer} = TantivyEx.IndexWriter.new(index)

    documents
    |> Enum.chunk_every(batch_size)
    |> Enum.each(fn batch ->
      Enum.each(batch, &TantivyEx.IndexWriter.add_document(writer, &1))
      TantivyEx.IndexWriter.commit(writer)
    end)

    index
  end
end
```

## Performance Best Practices Summary

### Do's ✅

- Batch document operations
- Use appropriate field types and options
- Monitor index size and performance
- Cache frequent queries
- Use specific, targeted queries
- Profile your application's search patterns

### Don'ts ❌

- Don't commit after every document
- Don't store fields you don't need to retrieve
- Don't use overly broad queries (`*`)
- Don't request more results than needed
- Don't ignore memory usage patterns
- Don't skip performance testing

### Monitoring in Production

```elixir
defmodule ProductionMonitoring do
  use GenServer
  require Logger

  def start_link(index_path) do
    GenServer.start_link(__MODULE__, %{index_path: index_path}, name: __MODULE__)
  end

  def init(state) do
    schedule_monitoring()
    {:ok, state}
  end

  def handle_info(:monitor, %{index_path: index_path} = state) do
    case IndexMonitor.check_index_stats(index_path) do
      {:ok, size_mb} ->
        :telemetry.execute([:tantivy_ex, :index, :size], %{megabytes: size_mb})

      {:error, reason} ->
        Logger.error("Index monitoring failed: #{inspect(reason)}")
    end

    schedule_monitoring()
    {:noreply, state}
  end

  defp schedule_monitoring do
    Process.send_after(self(), :monitor, 60_000)  # Every minute
  end
end
```
