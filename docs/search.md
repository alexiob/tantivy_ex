# Search Guide

This guide covers query types, search strategies, and best practices for searching with TantivyEx.

## Table of Contents

- [Basic Search](#basic-search)
- [Query Types](#query-types)
- [Search Parameters](#search-parameters)
- [Advanced Search Patterns](#advanced-search-patterns)
- [Performance Optimization](#performance-optimization)
- [Real-world Examples](#real-world-examples)

## Basic Search

### Simple Text Search

```elixir
alias TantivyEx.Index

# Open an existing index
{:ok, index} = Index.open("/path/to/index")

# Basic search - returns top 10 results
{:ok, results} = Index.search(index, "elixir programming", 10)

# Results format: list of documents matching the schema
results
# => [
#   %{"title" => "Introduction to Elixir", "content" => "...", "timestamp" => 1640995200},
#   %{"title" => "Advanced Elixir Patterns", "content" => "...", "timestamp" => 1640995300},
#   ...
# ]
```

### Search with Limits

```elixir
# Get different numbers of results
{:ok, top_5} = Index.search(index, "machine learning", 5)
{:ok, top_50} = Index.search(index, "machine learning", 50)

# Handle empty results
case Index.search(index, "nonexistent term", 10) do
  {:ok, []} -> IO.puts("No results found")
  {:ok, results} -> IO.puts("Found #{length(results)} results")
  {:error, reason} -> IO.puts("Search failed: #{inspect(reason)}")
end
```

## Query Types

### Full-Text Search

Full-text search works on fields indexed with `:TEXT` or `:TEXT_STORED` options:

```elixir
# Single term
{:ok, results} = Index.search(index, "elixir", 10)

# Multiple terms (AND by default)
{:ok, results} = Index.search(index, "elixir functional programming", 10)

# Phrase search with quotes
{:ok, results} = Index.search(index, "\"functional programming\"", 10)

# Partial matching
{:ok, results} = Index.search(index, "program*", 10)  # matches "programming", "program", etc.
```

### Field-Specific Search

Search within specific fields using field notation:

```elixir
# Search only in title field
{:ok, results} = Index.search(index, "title:elixir", 10)

# Search in multiple specific fields
{:ok, results} = Index.search(index, "title:elixir OR author:jose", 10)

# Combine field-specific and general search
{:ok, results} = Index.search(index, "title:elixir programming", 10)
```

### Boolean Queries

Use boolean operators for complex queries:

```elixir
# AND operator (explicit)
{:ok, results} = Index.search(index, "elixir AND phoenix", 10)

# OR operator
{:ok, results} = Index.search(index, "elixir OR erlang", 10)

# NOT operator
{:ok, results} = Index.search(index, "programming NOT javascript", 10)

# Complex boolean combinations
{:ok, results} = Index.search(index, "(elixir OR erlang) AND (web OR backend)", 10)

# Grouping with parentheses
{:ok, results} = Index.search(index, "title:(elixir OR phoenix) AND content:tutorial", 10)
```

### Range Queries

Search numeric and date fields with ranges:

```elixir
# Numeric range queries
{:ok, results} = Index.search(index, "price:[10.0 TO 100.0]", 10)
{:ok, results} = Index.search(index, "rating:[4.0 TO *]", 10)  # 4.0 and above
{:ok, results} = Index.search(index, "stock:[* TO 10]", 10)    # 10 and below

# Date range queries (Unix timestamps)
{:ok, results} = Index.search(index, "published_at:[1640995200 TO 1641081600]", 10)

# Exclusive ranges
{:ok, results} = Index.search(index, "price:{10.0 TO 100.0}", 10)  # excludes 10.0 and 100.0

# Open-ended ranges
{:ok, results} = Index.search(index, "timestamp:[1640995200 TO *]", 10)  # after date
{:ok, results} = Index.search(index, "price:[* TO 50.0]", 10)           # below price
```

### Facet Queries

Search hierarchical facet fields:

```elixir
# Exact facet match
{:ok, results} = Index.search(index, "category:\"/electronics/phones\"", 10)

# Facet prefix search
{:ok, results} = Index.search(index, "category:\"/electronics/*\"", 10)

# Multiple facet values
{:ok, results} = Index.search(index, "category:\"/books/fiction\" OR category:\"/books/sci-fi\"", 10)
```

### Fuzzy Search

Search with typo tolerance:

```elixir
# Fuzzy search with ~ operator
{:ok, results} = Index.search(index, "progrmming~", 10)  # matches "programming"
{:ok, results} = Index.search(index, "javascrpit~", 10)  # matches "javascript"

# Fuzzy search with edit distance
{:ok, results} = Index.search(index, "programming~2", 10)  # allows up to 2 character changes
```

### Wildcard Search

Pattern matching in search terms:

```elixir
# Wildcard at end
{:ok, results} = Index.search(index, "prog*", 10)  # matches "programming", "program", "progress"

# Wildcard at beginning
{:ok, results} = Index.search(index, "*ing", 10)   # matches "programming", "learning", "coding"

# Wildcard in middle
{:ok, results} = Index.search(index, "pro*ing", 10)  # matches "programming", "processing"

# Single character wildcard
{:ok, results} = Index.search(index, "te?t", 10)    # matches "test", "text"
```

## Search Parameters

### Controlling Result Count

```elixir
# Standard pagination approach
{:ok, page_1} = Index.search(index, "elixir", 20)   # First 20 results
{:ok, page_2} = Index.search(index, "elixir", 40)   # First 40 results (includes page 1)

# For proper pagination, you'd need to track offset manually
# or implement pagination in your application layer
```

### Search with Score Information

While TantivyEx doesn't expose scores directly, you can implement relevance ranking:

```elixir
defmodule MyApp.SearchRanker do
  def ranked_search(index, query, limit) do
    case Index.search(index, query, limit * 2) do
      {:ok, results} ->
        ranked_results =
          results
          |> Enum.map(&add_relevance_score(&1, query))
          |> Enum.sort_by(& &1.relevance_score, :desc)
          |> Enum.take(limit)

        {:ok, ranked_results}
      error -> error
    end
  end

  defp add_relevance_score(doc, query) do
    # Simple relevance scoring based on query term frequency
    query_terms = String.split(String.downcase(query))
    title_score = calculate_field_score(doc["title"], query_terms, 3.0)
    content_score = calculate_field_score(doc["content"], query_terms, 1.0)

    Map.put(doc, :relevance_score, title_score + content_score)
  end

  defp calculate_field_score(field_value, query_terms, weight) when is_binary(field_value) do
    field_lower = String.downcase(field_value)
    term_frequency =
      Enum.reduce(query_terms, 0, fn term, acc ->
        acc + count_occurrences(field_lower, term)
      end)

    term_frequency * weight
  end
  defp calculate_field_score(_, _, _), do: 0

  defp count_occurrences(text, term) do
    text
    |> String.split()
    |> Enum.count(&(&1 == term))
  end
end
```

## Advanced Search Patterns

### Multi-Field Search Strategy

```elixir
defmodule MyApp.AdvancedSearch do
  alias TantivyEx.Index

  def multi_field_search(index, query, options \\ []) do
    limit = Keyword.get(options, :limit, 10)

    # Build query targeting multiple fields with different weights
    enhanced_query = build_multi_field_query(query)

    case Index.search(index, enhanced_query, limit) do
      {:ok, results} -> {:ok, enhance_results(results, query)}
      error -> error
    end
  end

  defp build_multi_field_query(query) do
    query_terms = String.split(query)

    # Search in title (higher priority), content, and tags
    title_query = "title:(#{Enum.join(query_terms, " OR ")})"
    content_query = "content:(#{query})"
    tags_query = "tags:(#{Enum.join(query_terms, " OR ")})"

    "#{title_query} OR #{content_query} OR #{tags_query}"
  end

  defp enhance_results(results, original_query) do
    Enum.map(results, fn doc ->
      doc
      |> add_highlight_info(original_query)
      |> add_match_info(original_query)
    end)
  end

  defp add_highlight_info(doc, query) do
    # Simple highlighting - wrap matching terms
    query_terms =
      query
      |> String.downcase()
      |> String.split()

    highlighted_title = highlight_text(doc["title"], query_terms)
    highlighted_content = highlight_text(doc["content"], query_terms)

    doc
    |> Map.put("highlighted_title", highlighted_title)
    |> Map.put("highlighted_content", highlighted_content)
  end

  defp highlight_text(text, query_terms) when is_binary(text) do
    Enum.reduce(query_terms, text, fn term, acc ->
      String.replace(acc, ~r/#{Regex.escape(term)}/i, "<mark>\\0</mark>")
    end)
  end
  defp highlight_text(_, _), do: ""

  defp add_match_info(doc, query) do
    query_terms = String.split(String.downcase(query))
    title_matches = count_matches(doc["title"], query_terms)
    content_matches = count_matches(doc["content"], query_terms)

    Map.put(doc, "match_info", %{
      title_matches: title_matches,
      content_matches: content_matches,
      total_matches: title_matches + content_matches
    })
  end

  defp count_matches(text, query_terms) when is_binary(text) do
    text_lower = String.downcase(text)
    Enum.reduce(query_terms, 0, fn term, acc ->
      acc + length(String.split(text_lower, term)) - 1
    end)
  end
  defp count_matches(_, _), do: 0
end
```

### Filtered Search

Combine full-text search with filters:

```elixir
defmodule MyApp.FilteredSearch do
  def search_with_filters(index, query, filters, limit \\ 10) do
    full_query = build_filtered_query(query, filters)
    Index.search(index, full_query, limit)
  end

  defp build_filtered_query(query, filters) do
    filter_clauses =
      filters
      |> Enum.map(&build_filter_clause/1)
      |> Enum.join(" AND ")

    case filter_clauses do
      "" -> query
      filters -> "(#{query}) AND (#{filters})"
    end
  end

  defp build_filter_clause({:price_range, {min, max}}) do
    "price:[#{min} TO #{max}]"
  end

  defp build_filter_clause({:category, category}) do
    "category:\"#{category}\""
  end

  defp build_filter_clause({:date_after, timestamp}) do
    "published_at:[#{timestamp} TO *]"
  end

  defp build_filter_clause({:rating_above, rating}) do
    "rating:[#{rating} TO *]"
  end

  defp build_filter_clause({:tags, tags}) when is_list(tags) do
    tag_queries = Enum.map(tags, &"tags:#{&1}")
    "(#{Enum.join(tag_queries, " OR ")})"
  end
end

# Usage examples:
{:ok, results} = MyApp.FilteredSearch.search_with_filters(
  index,
  "elixir programming",
  [
    {:price_range, {10.0, 100.0}},
    {:category, "/books/programming"},
    {:rating_above, 4.0}
  ],
  20
)
```

### Search Suggestions

Implement search suggestions and autocomplete:

```elixir
defmodule MyApp.SearchSuggestions do
  alias TantivyEx.Index

  def get_suggestions(index, partial_query, limit \\ 5) do
    # Use wildcard search for suggestions
    suggestion_query = "#{partial_query}*"

    case Index.search(index, suggestion_query, limit * 3) do
      {:ok, results} ->
        suggestions =
          results
          |> extract_suggestion_terms(partial_query)
          |> Enum.uniq()
          |> Enum.take(limit)

        {:ok, suggestions}
      error -> error
    end
  end

  defp extract_suggestion_terms(results, partial_query) do
    Enum.flat_map(results, fn doc ->
      title_terms = extract_matching_terms(doc["title"], partial_query)
      content_terms = extract_matching_terms(doc["content"], partial_query)
      title_terms ++ content_terms
    end)
  end

  defp extract_matching_terms(text, partial_query) when is_binary(text) do
    text
    |> String.downcase()
    |> String.split(~r/\W+/)
    |> Enum.filter(&String.starts_with?(&1, String.downcase(partial_query)))
    |> Enum.filter(&(String.length(&1) > String.length(partial_query)))
  end
  defp extract_matching_terms(_, _), do: []

  def get_related_searches(index, query, limit \\ 5) do
    # Find documents similar to the query
    case Index.search(index, query, 20) do
      {:ok, results} ->
        related_terms =
          results
          |> extract_common_terms(query)
          |> Enum.take(limit)

        {:ok, related_terms}
      error -> error
    end
  end

  defp extract_common_terms(results, original_query) do
    original_terms = String.split(String.downcase(original_query))

    results
    |> Enum.flat_map(&extract_document_terms/1)
    |> Enum.frequencies()
    |> Enum.reject(fn {term, _freq} -> term in original_terms end)
    |> Enum.sort_by(fn {_term, freq} -> -freq end)
    |> Enum.map(fn {term, _freq} -> term end)
  end

  defp extract_document_terms(doc) do
    [doc["title"], doc["content"]]
    |> Enum.filter(&is_binary/1)
    |> Enum.flat_map(&String.split(&1, ~r/\W+/))
    |> Enum.map(&String.downcase/1)
    |> Enum.filter(&(String.length(&1) > 3))
  end
end
```

### Search Analytics

Track and analyze search patterns:

```elixir
defmodule MyApp.SearchAnalytics do
  alias TantivyEx.Index

  def search_with_analytics(index, query, user_id, limit \\ 10) do
    start_time = System.monotonic_time(:millisecond)

    result = Index.search(index, query, limit)

    end_time = System.monotonic_time(:millisecond)
    search_time = end_time - start_time

    # Log search analytics
    log_search_event(query, user_id, result, search_time)

    result
  end

  defp log_search_event(query, user_id, result, search_time) do
    event = %{
      query: query,
      user_id: user_id,
      timestamp: System.system_time(:second),
      search_time_ms: search_time,
      result_count: case result do
        {:ok, results} -> length(results)
        {:error, _} -> 0
      end,
      success: match(result, {:ok, _})
    }

    # Store analytics (could be database, file, external service)
    store_analytics_event(event)
  end

  defp store_analytics_event(event) do
    # Example: Log to file
    log_file = "search_analytics.log"
    log_entry = Jason.encode!(event) <> "\n"
    File.write!(log_file, log_entry, [:append])
  end

  def analyze_search_patterns(analytics_file) do
    analytics_file
    |> File.stream!()
    |> Stream.map(&Jason.decode!/1)
    |> Enum.reduce(%{}, &accumulate_analytics/2)
    |> generate_analytics_report()
  end

  defp accumulate_analytics(event, acc) do
    acc
    |> Map.update(:total_searches, 1, &(&1 + 1))
    |> Map.update(:unique_queries, MapSet.new([event["query"]]), &MapSet.put(&1, event["query"]))
    |> Map.update(:avg_search_time, [event["search_time_ms"]], &[event["search_time_ms"] | &1])
    |> Map.update(:query_frequency, %{}, &Map.update(&1, event["query"], 1, fn x -> x + 1 end))
  end

  defp generate_analytics_report(analytics) do
    search_times = analytics[:avg_search_time] || []
    avg_time = if length(search_times) > 0, do: Enum.sum(search_times) / length(search_times), else: 0

    %{
      total_searches: analytics[:total_searches] || 0,
      unique_queries: MapSet.size(analytics[:unique_queries] || MapSet.new()),
      average_search_time_ms: avg_time,
      popular_queries:
        analytics[:query_frequency]
        |> Enum.sort_by(fn {_query, freq} -> -freq end)
        |> Enum.take(10)
    }
  end
end
```

## Performance Optimization

### Query Optimization

```elixir
defmodule MyApp.QueryOptimizer do
  def optimize_query(query) do
    query
    |> String.trim()
    |> remove_stop_words()
    |> normalize_wildcards()
    |> balance_boolean_operators()
  end

  defp remove_stop_words(query) do
    stop_words = ~w(the a an and or but in on at to for of with by)

    query
    |> String.split()
    |> Enum.reject(&(String.downcase(&1) in stop_words))
    |> Enum.join(" ")
  end

  defp normalize_wildcards(query) do
    # Limit wildcard usage to prevent performance issues
    String.replace(query, ~r/\*{2,}/, "*")
  end

  defp balance_boolean_operators(query) do
    # Ensure balanced parentheses and proper operator usage
    query
    |> String.replace(~r/\s+(AND|OR)\s+/i, " \\1 ")
    |> String.replace(~r/\(\s*\)/, "")
  end
end
```

### Search Caching

```elixir
defmodule MyApp.SearchCache do
  use GenServer

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def cached_search(index, query, limit) do
    cache_key = {query, limit}

    case GenServer.call(__MODULE__, {:get, cache_key}) do
      {:hit, results} -> {:ok, results}
      :miss ->
        case TantivyEx.Index.search(index, query, limit) do
          {:ok, results} = success ->
            GenServer.cast(__MODULE__, {:put, cache_key, results})
            success
          error -> error
        end
    end
  end

  def clear_cache do
    GenServer.cast(__MODULE__, :clear)
  end

  # Server Implementation
  def init(_opts) do
    # Simple in-memory cache with TTL
    {:ok, %{cache: %{}, ttl_ms: 300_000}}  # 5 minute TTL
  end

  def handle_call({:get, key}, _from, state) do
    case Map.get(state.cache, key) do
      {results, timestamp} ->
        if System.monotonic_time(:millisecond) - timestamp < state.ttl_ms do
          {:reply, {:hit, results}, state}
        else
          new_cache = Map.delete(state.cache, key)
          {:reply, :miss, %{state | cache: new_cache}}
        end
      nil ->
        {:reply, :miss, state}
    end
  end

  def handle_cast({:put, key, results}, state) do
    timestamp = System.monotonic_time(:millisecond)
    new_cache = Map.put(state.cache, key, {results, timestamp})
    {:noreply, %{state | cache: new_cache}}
  end

  def handle_cast(:clear, state) do
    {:noreply, %{state | cache: %{}}}
  end
end
```

### Result Processing Optimization

```elixir
defmodule MyApp.ResultProcessor do
  def process_results_efficiently(results, processing_options \\ []) do
    results
    |> maybe_add_highlighting(processing_options[:highlight])
    |> maybe_add_metadata(processing_options[:metadata])
    |> maybe_limit_content(processing_options[:content_limit])
  end

  defp maybe_add_highlighting(results, nil), do: results
  defp maybe_add_highlighting(results, highlight_query) do
    # Only process highlighting if requested
    Enum.map(results, &add_highlighting(&1, highlight_query))
  end

  defp maybe_add_metadata(results, false), do: results
  defp maybe_add_metadata(results, _) do
    # Add metadata only if needed
    Enum.map(results, &add_metadata/1)
  end

  defp maybe_limit_content(results, nil), do: results
  defp maybe_limit_content(results, limit) do
    # Truncate content to reduce memory usage
    Enum.map(results, &limit_content(&1, limit))
  end

  defp add_highlighting(doc, query) do
    # Efficient highlighting implementation
    Map.put(doc, "highlighted_content", highlight_content(doc["content"], query))
  end

  defp add_metadata(doc) do
    Map.put(doc, "metadata", %{
      processed_at: System.system_time(:second),
      content_length: String.length(doc["content"] || "")
    })
  end

  defp limit_content(doc, limit) do
    case doc["content"] do
      content when is_binary(content) and byte_size(content) > limit ->
        truncated = String.slice(content, 0, limit) <> "..."
        Map.put(doc, "content", truncated)
      _ ->
        doc
    end
  end

  defp highlight_content(content, query) when is_binary(content) do
    # Simple but efficient highlighting
    query_terms = String.split(String.downcase(query))

    Enum.reduce(query_terms, content, fn term, acc ->
      String.replace(acc, ~r/#{Regex.escape(term)}/i, "<mark>\\0</mark>")
    end)
  end
  defp highlight_content(_, _), do: ""
end
```

## Real-world Examples

### E-commerce Search

```elixir
defmodule MyApp.EcommerceSearch do
  alias TantivyEx.Index

  def product_search(index, query, filters \\ %{}) do
    search_query = build_product_query(query, filters)

    case Index.search(index, search_query, 50) do
      {:ok, results} ->
        processed_results =
          results
          |> add_product_metadata()
          |> sort_by_relevance_and_availability()
          |> apply_business_rules()

        {:ok, processed_results}
      error -> error
    end
  end

  defp build_product_query(query, filters) do
    base_query = if query == "", do: "*", else: query

    filter_clauses = []

    # Price filter
    filter_clauses =
      case Map.get(filters, :price_range) do
        {min, max} -> ["price:[#{min} TO #{max}]" | filter_clauses]
        _ -> filter_clauses
      end

    # Category filter
    filter_clauses =
      case Map.get(filters, :category) do
        nil -> filter_clauses
        category -> ["category:\"#{category}\"" | filter_clauses]
      end

    # In stock filter
    filter_clauses =
      case Map.get(filters, :in_stock) do
        true -> ["stock:[1 TO *]" | filter_clauses]
        _ -> filter_clauses
      end

    # Rating filter
    filter_clauses =
      case Map.get(filters, :min_rating) do
        nil -> filter_clauses
        rating -> ["rating:[#{rating} TO *]" | filter_clauses]
      end

    # Combine query with filters
    case filter_clauses do
      [] -> base_query
      filters -> "(#{base_query}) AND (#{Enum.join(filters, " AND ")})"
    end
  end

  defp add_product_metadata(products) do
    Enum.map(products, fn product ->
      product
      |> Map.put("availability_status", get_availability_status(product))
      |> Map.put("shipping_estimate", calculate_shipping_estimate(product))
      |> Map.put("discount_info", calculate_discount(product))
    end)
  end

  defp sort_by_relevance_and_availability(products) do
    Enum.sort_by(products, fn product ->
      availability_score = case product["availability_status"] do
        "in_stock" -> 1000
        "low_stock" -> 500
        "out_of_stock" -> 0
      end

      rating_score = (product["rating"] || 0) * 100

      # Higher scores first (negative for desc sort)
      -(availability_score + rating_score)
    end)
  end

  defp apply_business_rules(products) do
    products
    |> promote_featured_products()
    |> hide_out_of_stock_if_alternatives_exist()
    |> add_recommendation_tags()
  end

  defp get_availability_status(product) do
    stock = product["stock"] || 0
    cond do
      stock > 10 -> "in_stock"
      stock > 0 -> "low_stock"
      true -> "out_of_stock"
    end
  end

  defp calculate_shipping_estimate(product) do
    # Business logic for shipping calculation
    case product["availability_status"] do
      "in_stock" -> "1-2 days"
      "low_stock" -> "3-5 days"
      "out_of_stock" -> "Not available"
    end
  end

  defp calculate_discount(product) do
    # Calculate discount information
    %{
      original_price: product["price"],
      discount_percent: 0,
      final_price: product["price"]
    }
  end

  defp promote_featured_products(products) do
    # Move featured products to the top
    {featured, regular} = Enum.split_with(products, &(&1["featured"] == true))
    featured ++ regular
  end

  defp hide_out_of_stock_if_alternatives_exist(products) do
    # Business rule: hide out of stock if similar products exist
    products  # Simplified - would implement actual logic
  end

  defp add_recommendation_tags(products) do
    Enum.map(products, fn product ->
      tags = []

      tags = if product["rating"] && product["rating"] > 4.5, do: ["top_rated" | tags], else: tags
      tags = if product["availability_status"] == "in_stock", do: ["available" | tags], else: tags
      tags = if product["price"] < 25.0, do: ["budget_friendly" | tags], else: tags

      Map.put(product, "recommendation_tags", tags)
    end)
  end
end
```

### Content Management Search

```elixir
defmodule MyApp.CMSSearch do
  alias TantivyEx.Index

  def content_search(index, query, user_permissions, options \\ []) do
    # Build search query with permission filtering
    search_query = build_content_query(query, user_permissions)
    limit = Keyword.get(options, :limit, 20)

    case Index.search(index, search_query, limit) do
      {:ok, results} ->
        processed_results =
          results
          |> filter_by_permissions(user_permissions)
          |> add_content_metadata()
          |> apply_content_ranking()

        {:ok, processed_results}
      error -> error
    end
  end

  defp build_content_query(query, permissions) do
    base_query = if query == "", do: "*", else: query

    # Add permission filters
    permission_filters = build_permission_filters(permissions)

    case permission_filters do
      "" -> base_query
      filters -> "(#{base_query}) AND (#{filters})"
    end
  end

  defp build_permission_filters(permissions) do
    filters = []

    # Published content filter
    filters = ["status:published" | filters]

    # User role filters
    if permissions.admin do
      # Admins can see everything
      ""
    else
      # Regular users see public content or their own
      user_filter = "author_id:#{permissions.user_id} OR visibility:public"
      Enum.join([user_filter | filters], " AND ")
    end
  end

  defp filter_by_permissions(results, permissions) do
    # Additional permission checking at result level
    Enum.filter(results, &can_user_access?(&1, permissions))
  end

  defp can_user_access?(content, permissions) do
    cond do
      permissions.admin -> true
      content["author_id"] == permissions.user_id -> true
      content["visibility"] == "public" -> true
      content["status"] == "published" -> true
      true -> false
    end
  end

  defp add_content_metadata(contents) do
    Enum.map(contents, fn content ->
      content
      |> Map.put("read_time", estimate_read_time(content["content"]))
      |> Map.put("freshness_score", calculate_freshness(content["published_at"]))
      |> Map.put("engagement_score", calculate_engagement(content))
    end)
  end

  defp estimate_read_time(content) when is_binary(content) do
    word_count = length(String.split(content))
    max(1, div(word_count, 200))  # Assume 200 words per minute
  end
  defp estimate_read_time(_), do: 1

  defp calculate_freshness(published_timestamp) when is_integer(published_timestamp) do
    now = System.system_time(:second)
    days_old = div(now - published_timestamp, 86400)
    max(0, 100 - days_old)  # Freshness score decreases over time
  end
  defp calculate_freshness(_), do: 0

  defp calculate_engagement(content) do
    # Simple engagement score based on available metrics
    view_count = content["view_count"] || 0
    comment_count = content["comment_count"] || 0
    share_count = content["share_count"] || 0

    view_count * 1 + comment_count * 5 + share_count * 10
  end

  defp apply_content_ranking(contents) do
    Enum.sort_by(contents, fn content ->
      freshness = content["freshness_score"] || 0
      engagement = content["engagement_score"] || 0

      # Combine scores (negative for descending sort)
      -(freshness + engagement)
    end)
  end
end
```

### Log Analysis Search

```elixir
defmodule MyApp.LogSearch do
  alias TantivyEx.Index

  def search_logs(index, query, filters \\ %{}, options \\ []) do
    search_query = build_log_query(query, filters)
    limit = Keyword.get(options, :limit, 100)

    case Index.search(index, search_query, limit) do
      {:ok, results} ->
        processed_results =
          results
          |> add_log_context()
          |> group_related_logs()
          |> sort_by_timestamp()

        {:ok, processed_results}
      error -> error
    end
  end

  defp build_log_query(query, filters) do
    base_query = if query == "", do: "*", else: query

    filter_clauses = []

    # Time range filter
    filter_clauses =
      case Map.get(filters, :time_range) do
        {start_time, end_time} ->
          ["timestamp:[#{start_time} TO #{end_time}]" | filter_clauses]
        _ -> filter_clauses
      end

    # Log level filter
    filter_clauses =
      case Map.get(filters, :level) do
        nil -> filter_clauses
        level -> ["level:#{level}" | filter_clauses]
      end

    # Service filter
    filter_clauses =
      case Map.get(filters, :service) do
        nil -> filter_clauses
        service -> ["service:#{service}" | filter_clauses]
      end

    # IP filter
    filter_clauses =
      case Map.get(filters, :client_ip) do
        nil -> filter_clauses
        ip -> ["client_ip:#{ip}" | filter_clauses]
      end

    case filter_clauses do
      [] -> base_query
      filters -> "(#{base_query}) AND (#{Enum.join(filters, " AND ")})"
    end
  end

  defp add_log_context(logs) do
    Enum.map(logs, fn log ->
      log
      |> Map.put("severity", determine_severity(log))
      |> Map.put("category", categorize_log(log))
      |> Map.put("formatted_timestamp", format_timestamp(log["timestamp"]))
    end)
  end

  defp determine_severity(log) do
    case String.upcase(log["level"] || "") do
      "ERROR" -> :high
      "WARN" -> :medium
      "INFO" -> :low
      "DEBUG" -> :low
      _ -> :unknown
    end
  end

  defp categorize_log(log) do
    message = String.downcase(log["message"] || "")

    cond do
      String.contains?(message, ["error", "exception", "failed"]) -> "error"
      String.contains?(message, ["login", "auth", "session"]) -> "authentication"
      String.contains?(message, ["request", "response", "http"]) -> "http"
      String.contains?(message, ["database", "query", "sql"]) -> "database"
      true -> "general"
    end
  end

  defp format_timestamp(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp)
    |> DateTime.to_string()
  end
  defp format_timestamp(_), do: "Unknown"

  defp group_related_logs(logs) do
    # Group logs by request_id or session
    logs
    |> Enum.group_by(&(&1["request_id"]))
    |> Enum.flat_map(fn {_request_id, group_logs} ->
      case length(group_logs) do
        1 -> group_logs
        _ ->
          # Mark related logs
          Enum.map(group_logs, fn log ->
            Map.put(log, "related_count", length(group_logs) - 1)
          end)
      end
    end)
  end

  defp sort_by_timestamp(logs) do
    Enum.sort_by(logs, &(&1["timestamp"]), :desc)
  end

  def analyze_log_patterns(index, time_range, pattern_type \\ :error) do
    filters = %{
      time_range: time_range,
      level: case pattern_type do
        :error -> "ERROR"
        :warning -> "WARN"
        _ -> nil
      end
    }

    case search_logs(index, "*", filters, limit: 1000) do
      {:ok, logs} ->
        patterns =
          logs
          |> extract_patterns(pattern_type)
          |> rank_patterns()

        {:ok, patterns}
      error -> error
    end
  end

  defp extract_patterns(logs, pattern_type) do
    case pattern_type do
      :error -> extract_error_patterns(logs)
      :ip -> extract_ip_patterns(logs)
      :service -> extract_service_patterns(logs)
    end
  end

  defp extract_error_patterns(logs) do
    logs
    |> Enum.map(&extract_error_signature/1)
    |> Enum.frequencies()
    |> Enum.map(fn {signature, count} ->
      %{type: "error", signature: signature, count: count}
    end)
  end

  defp extract_error_signature(log) do
    message = log["message"] || ""

    # Extract error patterns (simplified)
    cond do
      String.contains?(message, "timeout") -> "timeout_error"
      String.contains?(message, "connection") -> "connection_error"
      String.contains?(message, "permission") -> "permission_error"
      String.contains?(message, "not found") -> "not_found_error"
      true -> "generic_error"
    end
  end

  defp extract_ip_patterns(logs) do
    logs
    |> Enum.map(& &1["client_ip"])
    |> Enum.filter(&(&1 != nil))
    |> Enum.frequencies()
    |> Enum.map(fn {ip, count} ->
      %{type: "ip_activity", ip: ip, count: count}
    end)
  end

  defp extract_service_patterns(logs) do
    logs
    |> Enum.map(& &1["service"])
    |> Enum.filter(&(&1 != nil))
    |> Enum.frequencies()
    |> Enum.map(fn {service, count} ->
      %{type: "service_activity", service: service, count: count}
    end)
  end

  defp rank_patterns(patterns) do
    Enum.sort_by(patterns, & &1.count, :desc)
  end
end
```

## Best Practices Summary

1. **Query Construction**: Build queries programmatically to avoid syntax errors
2. **Result Processing**: Only process results that you need (highlighting, metadata, etc.)
3. **Caching**: Cache frequent queries to improve performance
4. **Error Handling**: Always handle search errors gracefully
5. **Security**: Filter results based on user permissions
6. **Performance**: Use appropriate limits and avoid overly broad queries
7. **Analytics**: Track search patterns to improve user experience
8. **Pagination**: Implement proper pagination for large result sets
9. **Query Optimization**: Optimize queries before executing them
10. **Field Strategy**: Use field-specific searches when possible for better performance
