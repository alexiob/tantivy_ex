# TantivyEx Documentation & Guides

Welcome to the TantivyEx documentation! This comprehensive guide will help you get started with TantivyEx, a high-performance full-text search engine for Elixir applications built on top of the Rust-based Tantivy library.

## 📚 Complete Guide Index

### 🚀 Getting Started

- **[Installation & Setup](#installation--setup)** - Get TantivyEx up and running in your project
- **[Quick Start Tutorial](#quick-start-tutorial)** - Build your first search index in 5 minutes
- **[Core Concepts](#core-concepts)** - Understanding indexes, schemas, and documents

### 📋 Core Documentation

1. **[Schema Design Guide](schema.md)** - Define your data structure and field types
   - Field types and options
   - Best practices for schema design
   - Performance considerations
   - Migration strategies

2. **[Indexing Guide](indexing.md)** - Add, update, and manage documents
   - Document indexing patterns
   - Batch operations
   - Index optimization
   - Real-time updates

3. **[Search Guide](search.md)** - Query your data effectively
   - Query types and syntax
   - Advanced search patterns
   - Performance optimization
   - Result handling

4. **[Tokenizers Guide](tokenizers.md)** - Text processing and analysis
   - Available tokenizers
   - Custom tokenization
   - Language-specific processing
   - Performance implications

### 🛠 Advanced Topics

- **[Performance Tuning](#performance-tuning)** - Optimize for speed and memory
- **[Production Deployment](#production-deployment)** - Best practices for production
- **[Monitoring & Debugging](#monitoring--debugging)** - Troubleshoot and monitor
- **[Integration Patterns](#integration-patterns)** - Common architectural patterns

### 🔧 API Reference

- **[Module Documentation](#module-documentation)** - Complete API reference
- **[Error Handling](#error-handling)** - Understanding error types and handling
- **[Configuration Options](#configuration-options)** - All available settings

### 📝 Examples & Recipes

- **[Common Use Cases](#common-use-cases)** - Real-world examples
- **[Code Recipes](#code-recipes)** - Copy-paste solutions
- **[Migration Examples](#migration-examples)** - Upgrading and data migration

---

## Installation & Setup

### Prerequisites

Before installing TantivyEx, ensure you have:

- **Elixir 1.12+** and **Erlang/OTP 24+**
- **Rust 1.70+** (for compiling the native library)
- **Git** (for dependency management)

### Installation

Add TantivyEx to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:tantivy_ex, "~> 0.1.0"}
  ]
end
```

Install dependencies:

```bash
mix deps.get
```

Compile the native library (this may take a few minutes on first compile):

```bash
mix compile
```

### Verification

Verify your installation with a simple test:

```elixir
# In iex -S mix
alias TantivyEx.{Index, Schema}

# Create a simple schema
{:ok, schema} = Schema.new()
{:ok, schema} = Schema.add_text_field(schema, "title", :text)
{:ok, schema} = Schema.add_text_field(schema, "content", :text)

# Create a temporary index
{:ok, index} = Index.create_in_ram(schema)

# Add a document
doc = %{"title" => "Hello TantivyEx", "content" => "This is a test document"}
{:ok, _} = Index.add_document(index, doc)

# Search
{:ok, results} = Index.search(index, "hello", 10)
IO.inspect(results)
# Should return: [%{"title" => "Hello TantivyEx", "content" => "This is a test document"}]
```

If this works without errors, your installation is successful!

---

## Quick Start Tutorial

Let's build a simple blog search engine in 5 minutes:

### Step 1: Define Your Schema

```elixir
alias TantivyEx.{Index, Schema}

# Create a new schema
{:ok, schema} = Schema.new()

# Add fields for a blog post
{:ok, schema} = Schema.add_text_field(schema, "title", :text_stored)
{:ok, schema} = Schema.add_text_field(schema, "content", :text)
{:ok, schema} = Schema.add_text_field(schema, "author", :text_stored)
{:ok, schema} = Schema.add_text_field(schema, "tags", :text)
{:ok, schema} = Schema.add_u64_field(schema, "published_at", :fast_stored)
{:ok, schema} = Schema.add_f64_field(schema, "rating", :fast_stored)
{:ok, schema} = Schema.add_facet_field(schema, "category", :facet)
```

### Step 2: Create Your Index

```elixir
# Create a persistent index
index_path = "/tmp/blog_search_index"
{:ok, index} = Index.create_in_dir(index_path, schema)

# Or create an in-memory index for testing
{:ok, index} = Index.create_in_ram(schema)
```

### Step 3: Add Documents

```elixir
# Sample blog posts
blog_posts = [
  %{
    "title" => "Getting Started with Elixir",
    "content" => "Elixir is a dynamic, functional language designed for building maintainable applications...",
    "author" => "Jane Doe",
    "tags" => "elixir functional programming beginner",
    "published_at" => 1640995200,
    "rating" => 4.5,
    "category" => "/programming/elixir"
  },
  %{
    "title" => "Advanced Phoenix Patterns",
    "content" => "Phoenix provides powerful abstractions for building real-time web applications...",
    "author" => "John Smith",
    "tags" => "phoenix web elixir advanced",
    "published_at" => 1641081600,
    "rating" => 4.8,
    "category" => "/programming/phoenix"
  },
  %{
    "title" => "Rust Performance Tips",
    "content" => "Rust offers zero-cost abstractions and memory safety without garbage collection...",
    "author" => "Alice Johnson",
    "tags" => "rust performance systems",
    "published_at" => 1641168000,
    "rating" => 4.2,
    "category" => "/programming/rust"
  }
]

# Add documents to the index
Enum.each(blog_posts, fn post ->
  {:ok, _} = Index.add_document(index, post)
end)

# Commit changes
{:ok, _} = Index.commit(index)
```

### Step 4: Search Your Content

```elixir
# Simple text search
{:ok, results} = Index.search(index, "elixir", 10)
IO.inspect(results, label: "Elixir posts")

# Search in specific fields
{:ok, results} = Index.search(index, "title:phoenix", 10)
IO.inspect(results, label: "Phoenix in title")

# Boolean queries
{:ok, results} = Index.search(index, "elixir AND phoenix", 10)
IO.inspect(results, label: "Elixir AND Phoenix")

# Range queries
{:ok, results} = Index.search(index, "rating:[4.0 TO *]", 10)
IO.inspect(results, label: "High-rated posts")

# Facet queries
{:ok, results} = Index.search(index, "category:\"/programming/elixir\"", 10)
IO.inspect(results, label: "Elixir category")
```

### Step 5: Handle Results

```elixir
defmodule BlogSearch do
  alias TantivyEx.Index

  def search_posts(index, query, limit \\ 10) do
    case Index.search(index, query, limit) do
      {:ok, results} ->
        formatted_results = Enum.map(results, &format_result/1)
        {:ok, formatted_results}

      {:error, reason} ->
        {:error, "Search failed: #{inspect(reason)}"}
    end
  end

  defp format_result(doc) do
    %{
      title: Map.get(doc, "title"),
      author: Map.get(doc, "author"),
      rating: Map.get(doc, "rating"),
      published_at: Map.get(doc, "published_at") |> format_timestamp(),
      snippet: Map.get(doc, "content") |> create_snippet(100)
    }
  end

  defp format_timestamp(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp) |> DateTime.to_string()
  end

  defp format_timestamp(_), do: "Unknown"

  defp create_snippet(content, max_length) when is_binary(content) do
    if String.length(content) <= max_length do
      content
    else
      content
      |> String.slice(0, max_length)
      |> String.trim_trailing()
      |> Kernel.<>("...")
    end
  end

  defp create_snippet(_, _), do: ""
end

# Use the search module
{:ok, formatted_results} = BlogSearch.search_posts(index, "elixir programming")
IO.inspect(formatted_results)
```

Congratulations! You now have a working full-text search engine. Continue reading the detailed guides to learn about advanced features and optimization techniques.

---

## Core Concepts

### What is TantivyEx?

TantivyEx is an Elixir wrapper around [Tantivy](https://github.com/quickwit-oss/tantivy), a full-text search engine library written in Rust. It provides:

- **High Performance**: Leverages Rust's memory safety and speed
- **Full-Text Search**: Advanced text processing and ranking
- **Flexible Schema**: Support for various field types and options
- **Real-Time Updates**: Add, update, and delete documents efficiently
- **Query Language**: Rich query syntax for complex searches

### Key Components

#### 1. Index

An **Index** is a data structure that stores your documents in a way that enables fast search operations. Think of it as a specialized database optimized for text search.

```elixir
# Create an index in memory (for testing)
{:ok, index} = Index.create_in_ram(schema)

# Create a persistent index (for production)
{:ok, index} = Index.create_in_dir("/path/to/index", schema)

# Open an existing index
{:ok, index} = Index.open("/path/to/index")
```

#### 2. Schema

A **Schema** defines the structure of your documents - what fields they have and how those fields should be processed and stored.

```elixir
{:ok, schema} = Schema.new()
{:ok, schema} = Schema.add_text_field(schema, "title", :text_stored)
{:ok, schema} = Schema.add_u64_field(schema, "timestamp", :fast_stored)
```

#### 3. Documents

**Documents** are the actual data you want to search. They must conform to your schema.

```elixir
document = %{
  "title" => "Introduction to Elixir",
  "timestamp" => 1640995200
}

{:ok, _} = Index.add_document(index, document)
```

#### 4. Fields

**Fields** are the individual pieces of data in your documents. Different field types are optimized for different use cases:

- **Text Fields**: For full-text search
- **Numeric Fields**: For range queries and sorting
- **Facet Fields**: For hierarchical filtering
- **Binary Fields**: For storing raw data

#### 5. Queries

**Queries** are how you search your index. TantivyEx supports a rich query language:

```elixir
# Simple term search
Index.search(index, "elixir", 10)

# Boolean queries
Index.search(index, "elixir AND phoenix", 10)

# Range queries
Index.search(index, "price:[10.0 TO 100.0]", 10)

# Field-specific search
Index.search(index, "title:elixir", 10)
```

### Data Flow

Understanding the data flow helps you design better search applications:

1. **Schema Definition** → Define your document structure
2. **Index Creation** → Create storage for your documents
3. **Document Addition** → Add your data to the index
4. **Commit** → Make changes searchable
5. **Query Execution** → Search and retrieve results

```elixir
# 1. Define schema
{:ok, schema} = Schema.new() |> Schema.add_text_field("title", :text_stored)

# 2. Create index
{:ok, index} = Index.create_in_ram(schema)

# 3. Add documents
{:ok, _} = Index.add_document(index, %{"title" => "Hello World"})

# 4. Commit (make searchable)
{:ok, _} = Index.commit(index)

# 5. Search
{:ok, results} = Index.search(index, "hello", 10)
```

---

## Performance Tuning

### Index Design for Performance

#### Choose the Right Field Options

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

#### Optimize Your Schema

```elixir
# ❌ Poor performance - storing large content unnecessarily
{:ok, schema} = Schema.add_text_field(schema, "full_content", :text_stored)

# ✅ Better - only index for search
{:ok, schema} = Schema.add_text_field(schema, "full_content", :text)

# Store a separate summary field for display
{:ok, schema} = Schema.add_text_field(schema, "summary", :text_stored)
```

### Indexing Performance

#### Batch Operations

Always prefer batch operations over individual document additions:

```elixir
# ❌ Slow - individual commits
Enum.each(documents, fn doc ->
  Index.add_document(index, doc)
  Index.commit(index)  # Don't do this!
end)

# ✅ Fast - batch commit
Enum.each(documents, fn doc ->
  Index.add_document(index, doc)
end)
Index.commit(index)  # Single commit at the end
```

#### Optimize Commit Frequency

```elixir
defmodule BulkIndexer do
  @batch_size 1000

  def index_documents(index, documents) do
    documents
    |> Enum.chunk_every(@batch_size)
    |> Enum.each(fn batch ->
      Enum.each(batch, &Index.add_document(index, &1))
      Index.commit(index)
    end)
  end
end
```

### Search Performance

#### Query Optimization

```elixir
# ❌ Slow - overly broad queries
Index.search(index, "*", 10000)

# ✅ Fast - specific queries with reasonable limits
Index.search(index, "specific terms", 50)

# ❌ Slow - complex boolean queries without field targeting
Index.search(index, "(a OR b OR c) AND (d OR e OR f)", 100)

# ✅ Fast - field-specific queries
Index.search(index, "title:(important terms) AND category:specific", 100)
```

#### Result Limiting

```elixir
# Don't retrieve more results than you need
{:ok, results} = Index.search(index, query, 20)  # Not 10000

# For pagination, consider your application's needs
def paginated_search(index, query, page, per_page) do
  # Simple approach - may not be efficient for deep pagination
  limit = page * per_page
  {:ok, all_results} = Index.search(index, query, limit)

  start_index = (page - 1) * per_page
  page_results = Enum.slice(all_results, start_index, per_page)

  {:ok, page_results}
end
```

### Memory Management

#### Index Size Monitoring

```elixir
defmodule IndexMonitor do
  def check_index_stats(index_path) do
    case File.stat(index_path) do
      {:ok, %{size: size}} ->
        size_mb = size / (1024 * 1024)
        IO.puts("Index size: #{Float.round(size_mb, 2)} MB")

      {:error, reason} ->
        IO.puts("Could not get index stats: #{reason}")
    end
  end
end
```

#### RAM vs Disk Indexes

```elixir
# Use RAM indexes for:
# - Testing
# - Small datasets (< 100MB)
# - Temporary indexes
{:ok, index} = Index.create_in_ram(schema)

# Use disk indexes for:
# - Production systems
# - Large datasets
# - Persistent storage needs
{:ok, index} = Index.create_in_dir("/var/lib/search_index", schema)
```

---

## Production Deployment

### Environment Configuration

#### Index Path Management

```elixir
# config/prod.exs
config :my_app, :search_index,
  path: System.get_env("SEARCH_INDEX_PATH", "/var/lib/myapp/search_index"),
  backup_path: System.get_env("SEARCH_BACKUP_PATH", "/var/lib/myapp/search_backup")

# lib/my_app/search_config.ex
defmodule MyApp.SearchConfig do
  def index_path do
    Application.get_env(:my_app, :search_index)[:path]
  end

  def backup_path do
    Application.get_env(:my_app, :search_index)[:backup_path]
  end
end
```

#### File Permissions

Ensure your application has proper permissions:

```bash
# Create index directory with proper ownership
sudo mkdir -p /var/lib/myapp/search_index
sudo chown myapp:myapp /var/lib/myapp/search_index
sudo chmod 755 /var/lib/myapp/search_index
```

### High Availability Patterns

#### Index Backup Strategy

```elixir
defmodule MyApp.SearchBackup do
  alias MyApp.SearchConfig

  def backup_index do
    source = SearchConfig.index_path()
    backup = SearchConfig.backup_path()
    timestamp = DateTime.utc_now() |> DateTime.to_unix() |> to_string()
    backup_dir = Path.join(backup, "backup_#{timestamp}")

    case File.cp_r(source, backup_dir) do
      {:ok, _} ->
        clean_old_backups(backup)
        {:ok, backup_dir}

      {:error, reason} ->
        {:error, "Backup failed: #{reason}"}
    end
  end

  defp clean_old_backups(backup_path, keep_count \\ 5) do
    backup_path
    |> File.ls!()
    |> Enum.filter(&String.starts_with?(&1, "backup_"))
    |> Enum.sort(:desc)
    |> Enum.drop(keep_count)
    |> Enum.each(fn old_backup ->
      File.rm_rf!(Path.join(backup_path, old_backup))
    end)
  end
end
```

#### Rolling Updates

```elixir
defmodule MyApp.SearchUpdater do
  def rolling_update(new_documents) do
    # 1. Create new index with updated documents
    temp_path = "/tmp/search_index_new"
    {:ok, new_index} = rebuild_index(temp_path, new_documents)

    # 2. Verify new index
    case verify_index(new_index) do
      :ok ->
        # 3. Atomically replace old index
        replace_index(temp_path)

      {:error, reason} ->
        File.rm_rf(temp_path)
        {:error, reason}
    end
  end

  defp verify_index(index) do
    # Run verification queries
    test_queries = ["test", "verify", "sample"]

    Enum.reduce_while(test_queries, :ok, fn query, acc ->
      case Index.search(index, query, 1) do
        {:ok, _} -> {:cont, acc}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp replace_index(new_path) do
    current_path = MyApp.SearchConfig.index_path()
    backup_path = "#{current_path}.backup"

    # Atomic replacement
    :ok = File.rename(current_path, backup_path)
    :ok = File.rename(new_path, current_path)

    # Clean up old backup
    spawn(fn ->
      Process.sleep(60_000)  # Wait 1 minute
      File.rm_rf(backup_path)
    end)
  end
end
```

### Monitoring & Health Checks

#### Health Check Implementation

```elixir
defmodule MyApp.SearchHealthCheck do
  alias TantivyEx.Index

  def health_check do
    %{
      status: check_index_status(),
      last_update: get_last_update_time(),
      document_count: get_document_count(),
      index_size: get_index_size(),
      response_time: measure_response_time()
    }
  end

  defp check_index_status do
    case Index.open(MyApp.SearchConfig.index_path()) do
      {:ok, _index} -> :healthy
      {:error, _} -> :unhealthy
    end
  end

  defp measure_response_time do
    start_time = System.monotonic_time(:millisecond)

    # Simple test query
    case MyApp.Search.simple_search("test", 1) do
      {:ok, _} ->
        end_time = System.monotonic_time(:millisecond)
        end_time - start_time

      {:error, _} ->
        :error
    end
  end

  defp get_document_count do
    # Implement based on your document tracking strategy
    # This could be stored in a separate counter or calculated
    :not_implemented
  end

  defp get_index_size do
    path = MyApp.SearchConfig.index_path()
    case File.stat(path) do
      {:ok, %{size: size}} -> size
      {:error, _} -> :unknown
    end
  end

  defp get_last_update_time do
    # Track this in your application state or file metadata
    :not_implemented
  end
end
```

#### Metrics Collection

```elixir
defmodule MyApp.SearchMetrics do
  use GenServer

  # Track search metrics
  def record_search(query, result_count, response_time) do
    GenServer.cast(__MODULE__, {:search, query, result_count, response_time})
  end

  def record_index_operation(operation, duration) do
    GenServer.cast(__MODULE__, {:index_op, operation, duration})
  end

  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  # GenServer implementation
  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, Map.merge(state, %{
      searches: [],
      index_operations: [],
      start_time: System.monotonic_time(:second)
    })}
  end

  def handle_cast({:search, query, count, time}, state) do
    searches = [%{query: query, count: count, time: time, timestamp: now()} | state.searches]
    # Keep only last 1000 searches
    searches = Enum.take(searches, 1000)
    {:noreply, %{state | searches: searches}}
  end

  def handle_cast({:index_op, operation, duration}, state) do
    ops = [%{operation: operation, duration: duration, timestamp: now()} | state.index_operations]
    ops = Enum.take(ops, 1000)
    {:noreply, %{state | index_operations: ops}}
  end

  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      uptime: System.monotonic_time(:second) - state.start_time,
      total_searches: length(state.searches),
      avg_response_time: calculate_avg_response_time(state.searches),
      recent_searches: Enum.take(state.searches, 10),
      index_operations: Enum.take(state.index_operations, 10)
    }
    {:reply, metrics, state}
  end

  defp now, do: System.monotonic_time(:second)

  defp calculate_avg_response_time([]), do: 0
  defp calculate_avg_response_time(searches) do
    total_time = Enum.reduce(searches, 0, fn %{time: time}, acc -> acc + time end)
    total_time / length(searches)
  end
end
```

---

## Integration Patterns

### GenServer-based Search Service

```elixir
defmodule MyApp.SearchService do
  use GenServer
  alias TantivyEx.Index

  @index_path "/var/lib/myapp/search_index"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API
  def search(query, limit \\ 10) do
    GenServer.call(__MODULE__, {:search, query, limit})
  end

  def add_document(document) do
    GenServer.call(__MODULE__, {:add_document, document})
  end

  def commit do
    GenServer.call(__MODULE__, :commit)
  end

  def reload_index do
    GenServer.call(__MODULE__, :reload_index)
  end

  # GenServer Callbacks
  def init(_opts) do
    case load_index() do
      {:ok, index} ->
        {:ok, %{index: index, uncommitted_changes: false}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  def handle_call({:search, query, limit}, _from, state) do
    result = Index.search(state.index, query, limit)
    {:reply, result, state}
  end

  def handle_call({:add_document, document}, _from, state) do
    case Index.add_document(state.index, document) do
      {:ok, result} ->
        new_state = %{state | uncommitted_changes: true}
        {:reply, {:ok, result}, new_state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:commit, _from, state) do
    case Index.commit(state.index) do
      {:ok, result} ->
        new_state = %{state | uncommitted_changes: false}
        {:reply, {:ok, result}, new_state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:reload_index, _from, state) do
    case load_index() do
      {:ok, new_index} ->
        new_state = %{state | index: new_index, uncommitted_changes: false}
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Auto-commit every 30 seconds if there are uncommitted changes
  def handle_info(:auto_commit, %{uncommitted_changes: true} = state) do
    Index.commit(state.index)
    schedule_auto_commit()
    {:noreply, %{state | uncommitted_changes: false}}
  end

  def handle_info(:auto_commit, state) do
    schedule_auto_commit()
    {:noreply, state}
  end

  defp load_index do
    case File.exists?(@index_path) do
      true -> Index.open(@index_path)
      false -> create_new_index()
    end
  end

  defp create_new_index do
    # Define your schema here
    {:ok, schema} = create_schema()
    Index.create_in_dir(@index_path, schema)
  end

  defp create_schema do
    alias TantivyEx.Schema

    {:ok, schema} = Schema.new()
    {:ok, schema} = Schema.add_text_field(schema, "title", :text_stored)
    {:ok, schema} = Schema.add_text_field(schema, "content", :text)
    {:ok, schema} = Schema.add_u64_field(schema, "timestamp", :fast_stored)
    {:ok, schema}
  end

  defp schedule_auto_commit do
    Process.send_after(self(), :auto_commit, 30_000)
  end
end
```

### Phoenix Integration

#### Search Controller

```elixir
defmodule MyAppWeb.SearchController do
  use MyAppWeb, :controller
  alias MyApp.SearchService

  def search(conn, %{"q" => query} = params) do
    limit = Map.get(params, "limit", "10") |> String.to_integer()

    case SearchService.search(query, limit) do
      {:ok, results} ->
        render(conn, :search, %{
          query: query,
          results: results,
          total: length(results)
        })

      {:error, reason} ->
        conn
        |> put_flash(:error, "Search failed: #{reason}")
        |> render(:search, %{query: query, results: [], total: 0})
    end
  end

  def suggest(conn, %{"q" => query}) do
    # Simple suggestion implementation
    case SearchService.search("#{query}*", 5) do
      {:ok, results} ->
        suggestions =
          results
          |> Enum.map(& Map.get(&1, "title"))
          |> Enum.uniq()

        json(conn, %{suggestions: suggestions})

      {:error, _} ->
        json(conn, %{suggestions: []})
    end
  end
end
```

#### LiveView Integration

```elixir
defmodule MyAppWeb.SearchLive do
  use MyAppWeb, :live_view
  alias MyApp.SearchService

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:query, "")
      |> assign(:results, [])
      |> assign(:loading, false)

    {:ok, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    send(self(), {:perform_search, query})

    socket =
      socket
      |> assign(:query, query)
      |> assign(:loading, true)

    {:noreply, socket}
  end

  def handle_info({:perform_search, query}, socket) do
    results =
      case SearchService.search(query, 20) do
        {:ok, results} -> results
        {:error, _} -> []
      end

    socket =
      socket
      |> assign(:results, results)
      |> assign(:loading, false)

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="search-container">
      <form phx-change="search" phx-submit="search">
        <input
          type="text"
          name="query"
          value={@query}
          placeholder="Search..."
          class="search-input"
        />
      </form>

      <%= if @loading do %>
        <div class="loading">Searching...</div>
      <% else %>
        <div class="results">
          <%= for result <- @results do %>
            <div class="result-item">
              <h3><%= Map.get(result, "title") %></h3>
              <p><%= Map.get(result, "content") |> truncate(200) %></p>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp truncate(text, length) when is_binary(text) do
    if String.length(text) <= length do
      text
    else
      String.slice(text, 0, length) <> "..."
    end
  end

  defp truncate(_, _), do: ""
end
```

### Task-based Indexing

```elixir
defmodule MyApp.IndexingTask do
  use Task
  alias MyApp.SearchService

  def start_link(documents) do
    Task.start_link(__MODULE__, :run, [documents])
  end

  def run(documents) do
    documents
    |> Enum.chunk_every(100)
    |> Enum.each(&process_batch/1)

    SearchService.commit()
  end

  defp process_batch(batch) do
    Enum.each(batch, fn document ->
      SearchService.add_document(document)
    end)
  end
end

# Usage
documents = fetch_documents_from_database()
MyApp.IndexingTask.start_link(documents)
```

---

This comprehensive guide provides everything you need to build, deploy, and maintain search functionality with TantivyEx. Continue reading the specific guides for detailed information on each topic.
