# Quick Start Tutorial

Let's build a simple blog search engine in 5 minutes:

## Step 1: Define Your Schema

```elixir
alias TantivyEx.{Index, Schema}

# Create a new schema
schema = Schema.new()

# Add fields for a blog post
schema = Schema.add_text_field(schema, "title", :text_stored)
schema = Schema.add_text_field(schema, "content", :text)
schema = Schema.add_text_field(schema, "author", :text_stored)
schema = Schema.add_text_field(schema, "tags", :text)
schema = Schema.add_u64_field(schema, "published_at", :fast_stored)
schema = Schema.add_f64_field(schema, "rating", :fast_stored)
schema = Schema.add_facet_field(schema, "category", :facet)
```

## Step 2: Create Your Index

```elixir
# Create a persistent index
index_path = "/tmp/blog_search_index"
{:ok, index} = Index.create_in_dir(index_path, schema)

# Or create an in-memory index for testing
{:ok, index} = Index.create_in_ram(schema)
```

## Step 3: Add Documents

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
{:ok, writer} = TantivyEx.IndexWriter.new(index)

Enum.each(blog_posts, fn post ->
  :ok = TantivyEx.IndexWriter.add_document(writer, post)
end)

# Commit changes
:ok = TantivyEx.IndexWriter.commit(writer)
```

## Step 4: Search Your Content

```elixir
# Simple text search
{:ok, searcher} = TantivyEx.Searcher.new(index)
{:ok, results} = TantivyEx.Searcher.search(searcher, "elixir", 10)
IO.inspect(results, label: "Elixir posts")

# Search in specific fields
{:ok, results} = TantivyEx.Searcher.search(searcher, "title:phoenix", 10)
IO.inspect(results, label: "Phoenix in title")

# Boolean queries
{:ok, results} = TantivyEx.Searcher.search(searcher, "elixir AND phoenix", 10)
IO.inspect(results, label: "Elixir AND Phoenix")

# Range queries
{:ok, results} = TantivyEx.Searcher.search(searcher, "rating:[4.0 TO *]", 10)
IO.inspect(results, label: "High-rated posts")

# Facet queries
{:ok, results} = TantivyEx.Searcher.search(searcher, "category:\"/programming/elixir\"", 10)
IO.inspect(results, label: "Elixir category")
```

## Step 5: Handle Results

```elixir
defmodule BlogSearch do
  alias TantivyEx.Index

  def search_posts(index, query, limit \\ 10) do
    {:ok, searcher} = TantivyEx.Searcher.new(index)
    case TantivyEx.Searcher.search(searcher, query, limit) do
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

## Next Steps

Congratulations! You now have a working full-text search engine. Here's what you can explore next:

- **[Core Concepts](core-concepts.md)** - Understand the fundamental building blocks
- **[Schema Design Guide](schema.md)** - Learn advanced schema design patterns
- **[Search Guide](search.md)** - Master advanced query techniques
- **[Performance Tuning](performance-tuning.md)** - Optimize for production workloads
- **[Production Deployment](production-deployment.md)** - Deploy in production environments

## Common Next Steps

### Adding More Fields

Extend your schema with additional field types:

```elixir
# Add more field types
{:ok, schema} = Schema.add_bytes_field(schema, "thumbnail", :stored)
{:ok, schema} = Schema.add_bool_field(schema, "is_published", :fast_stored)
{:ok, schema} = Schema.add_date_field(schema, "created_at", :fast_stored)
```

### Real-time Updates

Learn how to update documents in real-time:

```elixir
# Update an existing document
{:ok, writer} = TantivyEx.IndexWriter.new(index)
updated_doc = %{"title" => "Updated Elixir Guide", "content" => "..."}
:ok = TantivyEx.IndexWriter.update_document(writer, "title:\"Getting Started with Elixir\"", updated_doc)
:ok = TantivyEx.IndexWriter.commit(writer)
```

### Advanced Searching

Explore complex queries and filters:

```elixir
# Complex boolean queries
{:ok, results} = TantivyEx.Searcher.search(searcher, "(elixir OR phoenix) AND rating:[4.0 TO *]", 10)

# Faceted search
{:ok, results} = TantivyEx.Searcher.search_with_facets(searcher, "programming", ["category", "author"], 10)
```
