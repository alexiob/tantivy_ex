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

Full-text search works on fields indexed with `:text` or `::text_stored` options:

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

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Simple relevance scoring based on term frequency
  defp add_relevance_score(document, query) do
    query_terms = extract_query_terms(query)

    title_score = calculate_field_score(document["title"], query_terms, 2.0)
    content_score = calculate_field_score(document["content"], query_terms, 1.0)

    total_score = title_score + content_score

    Map.put(document, :relevance_score, total_score)
  end

  defp extract_query_terms(query) do
    query
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, "")
    |> String.split()
    |> Enum.reject(&(&1 in ["and", "or", "not"]))
  end

  defp calculate_field_score(field_value, query_terms, weight) when is_binary(field_value) do
    field_lower = String.downcase(field_value)

    term_frequency =
      query_terms
      |> Enum.map(fn term ->
        matches = Regex.scan(~r/#{Regex.escape(term)}/, field_lower)
        length(matches)
      end)
      |> Enum.sum()

    term_frequency * weight
  end

  defp calculate_field_score(_field_value, _query_terms, _weight), do: 0.0
end
```

## Advanced Search Patterns

### Query Building with the Query Module

For complex queries, use the `Query` module for programmatic query construction:

```elixir
alias TantivyEx.{Index, Query}

# Create a query parser
{:ok, parser} = Query.parser(index, ["title", "content"])

# Term queries
{:ok, term_query} = Query.term(parser, "field", "value")
{:ok, results} = Index.search_with_query(index, term_query, 10)

# Phrase queries
{:ok, phrase_query} = Query.phrase(parser, "field", ["exact", "phrase"])
{:ok, results} = Index.search_with_query(index, phrase_query, 10)

# Range queries
{:ok, range_query} = Query.range(parser, "price", 10.0, 100.0, true, true)
{:ok, results} = Index.search_with_query(index, range_query, 10)

# Boolean queries
{:ok, bool_query} = Query.boolean(parser)
{:ok, bool_query} = Query.add_must(bool_query, term_query)
{:ok, bool_query} = Query.add_should(bool_query, phrase_query)
{:ok, results} = Index.search_with_query(index, bool_query, 10)

# Fuzzy queries with edit distance
{:ok, fuzzy_query} = Query.fuzzy_term(parser, "field", "misspeled", 2)
{:ok, results} = Index.search_with_query(index, fuzzy_query, 10)
```

### Search Result Processing

Transform and enrich search results for your application:

```elixir
defmodule MyApp.SearchProcessor do
  def process_search_results(results, query, opts \\ []) do
    results
    |> add_highlights(query, opts)
    |> add_snippets(query, opts)
    |> add_metadata(opts)
    |> format_for_api()
  end

  defp add_highlights(results, query, opts) do
    highlight_length = Keyword.get(opts, :highlight_length, 200)

    Enum.map(results, fn doc ->
      highlighted_title = highlight_text(doc["title"], query, highlight_length)
      highlighted_content = highlight_text(doc["content"], query, highlight_length)

      Map.merge(doc, %{
        "title_highlighted" => highlighted_title,
        "content_highlighted" => highlighted_content
      })
    end)
  end

  defp add_snippets(results, query, opts) do
    snippet_length = Keyword.get(opts, :snippet_length, 300)

    Enum.map(results, fn doc ->
      snippet = extract_snippet(doc["content"], query, snippet_length)
      Map.put(doc, "snippet", snippet)
    end)
  end

  defp add_metadata(results, opts) do
    include_score = Keyword.get(opts, :include_score, false)
    include_position = Keyword.get(opts, :include_position, true)

    results
    |> Enum.with_index()
    |> Enum.map(fn {doc, index} ->
      metadata = %{}

      metadata = if include_position do
        Map.put(metadata, "position", index + 1)
      else
        metadata
      end

      metadata = if include_score && Map.has_key?(doc, :relevance_score) do
        Map.put(metadata, "score", doc.relevance_score)
      else
        metadata
      end

      Map.put(doc, "_metadata", metadata)
    end)
  end

  defp format_for_api(results) do
    %{
      "results" => results,
      "count" => length(results),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp highlight_text(text, query, max_length) when is_binary(text) do
    # Simple highlighting - mark query terms with <mark> tags
    query_terms = String.split(String.downcase(query))

    highlighted =
      Enum.reduce(query_terms, text, fn term, acc ->
        Regex.replace(
          ~r/#{Regex.escape(term)}/i,
          acc,
          "<mark>\\0</mark>"
        )
      end)

    if String.length(highlighted) > max_length do
      String.slice(highlighted, 0, max_length) <> "..."
    else
      highlighted
    end
  end

  defp highlight_text(_text, _query, _max_length), do: ""

  defp extract_snippet(content, query, max_length) when is_binary(content) do
    query_terms = String.split(String.downcase(query))
    content_lower = String.downcase(content)

    # Find the first occurrence of any query term
    first_match_pos =
      query_terms
      |> Enum.map(fn term -> String.contains?(content_lower, term) && :binary.match(content_lower, term) end)
      |> Enum.reject(&(&1 == false))
      |> Enum.map(fn {pos, _len} -> pos end)
      |> Enum.min(fn -> 0 end)

    # Extract snippet around the match
    start_pos = max(0, first_match_pos - div(max_length, 3))
    snippet = String.slice(content, start_pos, max_length)

    # Add ellipsis if truncated
    snippet = if start_pos > 0, do: "..." <> snippet, else: snippet
    snippet = if String.length(content) > start_pos + max_length, do: snippet <> "...", else: snippet

    snippet
  end

  defp extract_snippet(_content, _query, _max_length), do: ""
end
```

### Search Aggregations and Analytics

Implement search analytics to understand user behavior:

```elixir
defmodule MyApp.SearchAnalytics do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def track_search(query, result_count, user_id \\ nil) do
    GenServer.cast(__MODULE__, {:track_search, query, result_count, user_id, DateTime.utc_now()})
  end

  def track_click(query, document_id, position, user_id \\ nil) do
    GenServer.cast(__MODULE__, {:track_click, query, document_id, position, user_id, DateTime.utc_now()})
  end

  def get_search_stats(timeframe \\ :today) do
    GenServer.call(__MODULE__, {:get_stats, timeframe})
  end

  def get_popular_queries(limit \\ 10, timeframe \\ :today) do
    GenServer.call(__MODULE__, {:get_popular_queries, limit, timeframe})
  end

  def get_zero_result_queries(limit \\ 10, timeframe \\ :today) do
    GenServer.call(__MODULE__, {:get_zero_result_queries, limit, timeframe})
  end

  # GenServer implementation
  def init(state) do
    # In production, you'd want to persist this data
    {:ok, %{
      searches: [],
      clicks: []
    }}
  end

  def handle_cast({:track_search, query, result_count, user_id, timestamp}, state) do
    search_event = %{
      query: query,
      result_count: result_count,
      user_id: user_id,
      timestamp: timestamp
    }

    new_searches = [search_event | state.searches]
    {:noreply, %{state | searches: new_searches}}
  end

  def handle_cast({:track_click, query, document_id, position, user_id, timestamp}, state) do
    click_event = %{
      query: query,
      document_id: document_id,
      position: position,
      user_id: user_id,
      timestamp: timestamp
    }

    new_clicks = [click_event | state.clicks]
    {:noreply, %{state | clicks: new_clicks}}
  end

  def handle_call({:get_stats, timeframe}, _from, state) do
    timeframe_start = get_timeframe_start(timeframe)

    recent_searches =
      state.searches
      |> Enum.filter(&(DateTime.compare(&1.timestamp, timeframe_start) != :lt))

    recent_clicks =
      state.clicks
      |> Enum.filter(&(DateTime.compare(&1.timestamp, timeframe_start) != :lt))

    stats = %{
      total_searches: length(recent_searches),
      total_clicks: length(recent_clicks),
      zero_result_searches: Enum.count(recent_searches, &(&1.result_count == 0)),
      average_results: calculate_average_results(recent_searches),
      click_through_rate: calculate_ctr(recent_searches, recent_clicks)
    }

    {:reply, stats, state}
  end

  def handle_call({:get_popular_queries, limit, timeframe}, _from, state) do
    timeframe_start = get_timeframe_start(timeframe)

    popular_queries =
      state.searches
      |> Enum.filter(&(DateTime.compare(&1.timestamp, timeframe_start) != :lt))
      |> Enum.group_by(& &1.query)
      |> Enum.map(fn {query, searches} -> {query, length(searches)} end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(limit)

    {:reply, popular_queries, state}
  end

  def handle_call({:get_zero_result_queries, limit, timeframe}, _from, state) do
    timeframe_start = get_timeframe_start(timeframe)

    zero_result_queries =
      state.searches
      |> Enum.filter(&(DateTime.compare(&1.timestamp, timeframe_start) != :lt))
      |> Enum.filter(&(&1.result_count == 0))
      |> Enum.group_by(& &1.query)
      |> Enum.map(fn {query, searches} -> {query, length(searches)} end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(limit)

    {:reply, zero_result_queries, state}
  end

  defp get_timeframe_start(:today) do
    DateTime.utc_now() |> DateTime.add(-24, :hour)
  end

  defp get_timeframe_start(:week) do
    DateTime.utc_now() |> DateTime.add(-7, :day)
  end

  defp get_timeframe_start(:month) do
    DateTime.utc_now() |> DateTime.add(-30, :day)
  end

  defp calculate_average_results([]), do: 0.0
  defp calculate_average_results(searches) do
    total_results = Enum.sum(Enum.map(searches, & &1.result_count))
    total_results / length(searches)
  end

  defp calculate_ctr([], _clicks), do: 0.0
  defp calculate_ctr(searches, clicks) do
    search_queries = MapSet.new(searches, & &1.query)
    relevant_clicks = Enum.filter(clicks, &MapSet.member?(search_queries, &1.query))

    if length(searches) > 0 do
      length(relevant_clicks) / length(searches)
    else
      0.0
    end
  end
end
```

### Multi-Field Search Strategies

Implement sophisticated multi-field search with field boosting:

```elixir
defmodule MyApp.MultiFieldSearch do
  alias TantivyEx.{Index, Query}

  def search_with_field_boosting(index, query_string, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    # Define field weights
    field_weights = %{
      "title" => 3.0,
      "description" => 2.0,
      "content" => 1.0,
      "tags" => 1.5
    }

    # Build complex query
    {:ok, parser} = Query.parser(index, Map.keys(field_weights))
    {:ok, bool_query} = Query.boolean(parser)

    # Add weighted queries for each field
    bool_query =
      Enum.reduce(field_weights, bool_query, fn {field, weight}, acc_query ->
        field_query_string = "#{field}:(#{query_string})^#{weight}"

        case Query.parse(parser, field_query_string) do
          {:ok, field_query} ->
            {:ok, updated_query} = Query.add_should(acc_query, field_query)
            updated_query
          {:error, _} ->
            acc_query
        end
      end)

    # Execute search
    case Index.search_with_query(index, bool_query, limit) do
      {:ok, results} -> {:ok, results}
      {:error, reason} -> {:error, reason}
    end
  end

  def search_with_fallbacks(index, query_string, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    # Try exact phrase search first
    case exact_phrase_search(index, query_string, limit) do
      {:ok, results} when length(results) > 0 ->
        {:ok, %{results: results, strategy: "exact_phrase"}}

      _ ->
        # Fall back to AND search
        case and_search(index, query_string, limit) do
          {:ok, results} when length(results) > 0 ->
            {:ok, %{results: results, strategy: "and_search"}}

          _ ->
            # Fall back to OR search
            case or_search(index, query_string, limit) do
              {:ok, results} when length(results) > 0 ->
                {:ok, %{results: results, strategy: "or_search"}}

              _ ->
                # Final fallback to fuzzy search
                case fuzzy_search(index, query_string, limit) do
                  {:ok, results} ->
                    {:ok, %{results: results, strategy: "fuzzy_search"}}

                  error ->
                    error
                end
            end
        end
    end
  end

  defp exact_phrase_search(index, query_string, limit) do
    Index.search(index, "\"#{query_string}\"", limit)
  end

  defp and_search(index, query_string, limit) do
    terms = String.split(query_string)
    and_query = Enum.join(terms, " AND ")
    Index.search(index, and_query, limit)
  end

  defp or_search(index, query_string, limit) do
    terms = String.split(query_string)
    or_query = Enum.join(terms, " OR ")
    Index.search(index, or_query, limit)
  end

  defp fuzzy_search(index, query_string, limit) do
    terms = String.split(query_string)
    fuzzy_terms = Enum.map(terms, &(&1 <> "~"))
    fuzzy_query = Enum.join(fuzzy_terms, " OR ")
    Index.search(index, fuzzy_query, limit)
  end
end
```

### Search Filters and Faceting

Implement advanced filtering and faceted search:

```elixir
defmodule MyApp.FacetedSearch do
  alias TantivyEx.Index

  def search_with_filters(index, query_string, filters \\ %{}, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    # Build the base query
    base_query = if String.trim(query_string) == "" do
      "*"  # Match all if no search terms
    else
      query_string
    end

    # Add filters to the query
    filtered_query = apply_filters(base_query, filters)

    case Index.search(index, filtered_query, limit) do
      {:ok, results} ->
        # Generate facets for the current result set
        facets = generate_facets(results)
        {:ok, %{results: results, facets: facets}}

      error -> error
    end
  end

  defp apply_filters(base_query, filters) when map_size(filters) == 0 do
    base_query
  end

  defp apply_filters(base_query, filters) do
    filter_clauses =
      filters
      |> Enum.map(&build_filter_clause/1)
      |> Enum.reject(&is_nil/1)

    if length(filter_clauses) > 0 do
      filter_string = Enum.join(filter_clauses, " AND ")
      "(#{base_query}) AND (#{filter_string})"
    else
      base_query
    end
  end

  defp build_filter_clause({"price_range", %{"min" => min, "max" => max}}) do
    "price:[#{min} TO #{max}]"
  end

  defp build_filter_clause({"category", categories}) when is_list(categories) do
    category_clauses = Enum.map(categories, &"category:\"#{&1}\"")
    "(#{Enum.join(category_clauses, " OR ")})"
  end

  defp build_filter_clause({"category", category}) when is_binary(category) do
    "category:\"#{category}\""
  end

  defp build_filter_clause({"date_range", %{"start" => start_date, "end" => end_date}}) do
    start_timestamp = date_to_timestamp(start_date)
    end_timestamp = date_to_timestamp(end_date)
    "published_at:[#{start_timestamp} TO #{end_timestamp}]"
  end

  defp build_filter_clause({"rating_min", min_rating}) do
    "rating:[#{min_rating} TO *]"
  end

  defp build_filter_clause({"in_stock", true}) do
    "stock:[1 TO *]"
  end

  defp build_filter_clause({"in_stock", false}) do
    "stock:0"
  end

  defp build_filter_clause({field, value}) when is_binary(value) do
    "#{field}:\"#{value}\""
  end

  defp build_filter_clause(_), do: nil

  defp generate_facets(results) do
    %{
      "categories" => generate_category_facets(results),
      "price_ranges" => generate_price_facets(results),
      "ratings" => generate_rating_facets(results),
      "availability" => generate_availability_facets(results)
    }
  end

  defp generate_category_facets(results) do
    results
    |> Enum.map(& &1["category"])
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  defp generate_price_facets(results) do
    price_ranges = [
      {"Under $25", 0, 25},
      {"$25 - $50", 25, 50},
      {"$50 - $100", 50, 100},
      {"$100 - $200", 100, 200},
      {"Over $200", 200, :infinity}
    ]

    prices = Enum.map(results, & &1["price"]) |> Enum.reject(&is_nil/1)

    Enum.map(price_ranges, fn {label, min, max} ->
      count =
        if max == :infinity do
          Enum.count(prices, &(&1 >= min))
        else
          Enum.count(prices, &(&1 >= min and &1 < max))
        end

      {label, count}
    end)
  end

  defp generate_rating_facets(results) do
    [5, 4, 3, 2, 1]
    |> Enum.map(fn rating ->
      count = Enum.count(results, fn result ->
        case result["rating"] do
          nil -> false
          r when is_number(r) -> r >= rating and r < rating + 1
          _ -> false
        end
      end)

      {"#{rating} stars & up", count}
    end)
  end

  defp generate_availability_facets(results) do
    in_stock_count = Enum.count(results, fn result ->
      case result["stock"] do
        nil -> false
        stock when is_number(stock) -> stock > 0
        _ -> false
      end
    end)

    out_of_stock_count = length(results) - in_stock_count

    [
      {"In Stock", in_stock_count},
      {"Out of Stock", out_of_stock_count}
    ]
  end

  defp date_to_timestamp(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        date
        |> DateTime.new!(~T[00:00:00])
        |> DateTime.to_unix()

      {:error, _} -> 0
    end
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
