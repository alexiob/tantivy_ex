# Search Results Guide

This comprehensive guide covers search result processing, formatting, and optimization in TantivyEx, including result handling, highlighting, pagination, and advanced result processing techniques.

## Table of Contents

- [Search Results Fundamentals](#search-results-fundamentals)
- [Basic Result Processing](#basic-result-processing)
- [Result Structure and Format](#result-structure-and-format)
- [Result Enhancement](#result-enhancement)
- [Highlighting and Snippets](#highlighting-and-snippets)
- [Pagination and Limiting](#pagination-and-limiting)
- [Performance Optimization](#performance-optimization)
- [Advanced Processing](#advanced-processing)
- [Result Analytics](#result-analytics)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Search Results Fundamentals

### What are Search Results?

Search results in TantivyEx represent documents that match your query, along with metadata like relevance scores, document IDs, and optionally highlighted text snippets. Results are returned as structured data that can be processed, formatted, and enhanced for your application's needs.

```elixir
# Basic search result structure
%{
  score: 1.2345,           # Relevance score
  doc_id: 42,              # Internal document ID
  document: %{             # Document fields
    "title" => "Sample Document",
    "content" => "Document content...",
    "author" => "John Doe",
    "published_at" => "2024-01-15T10:30:00Z"
  }
}
```

### Result Components

Each search result contains:

- **Score**: Numerical relevance score (higher = more relevant)
- **Document ID**: Internal Tantivy document identifier
- **Document Fields**: Actual field values from the indexed document
- **Optional Metadata**: Highlighting, snippets, and computed fields

## Basic Result Processing

### Simple Search and Results

Perform a basic search and handle results:

```elixir
# Create/open index and create searcher
{:ok, index} = TantivyEx.Index.create_in_dir("path/to/index", schema)
{:ok, searcher} = TantivyEx.Searcher.new(index)

# Create query parser
{:ok, query_parser} = TantivyEx.Query.parser(schema, ["title", "content"])
{:ok, query} = TantivyEx.Query.parse(query_parser, "elixir programming")

# Execute search
{:ok, results} = TantivyEx.Searcher.search(searcher, query, 10)

# Process results
Enum.each(results, fn {score, document} ->
  IO.puts("Score: #{score}")
  IO.puts("Title: #{document["title"]}")
  IO.puts("---")
end)
```

### Accessing Result Data

Extract different types of data from results:

```elixir
defmodule MyApp.ResultProcessor do
  def process_search_results(results) do
    results
    |> Enum.map(&extract_result_data/1)
    |> Enum.sort_by(& &1.score, :desc)
  end

  defp extract_result_data({score, document}) do
    %{
      score: score,
      title: Map.get(document, "title", "Untitled"),
      content: Map.get(document, "content", ""),
      author: Map.get(document, "author", "Unknown"),
      published_at: parse_date(document["published_at"]),
      url: generate_url(document["id"])
    }
  end

  defp parse_date(nil), do: nil
  defp parse_date(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _} -> datetime
      {:error, _} -> nil
    end
  end

  defp generate_url(doc_id) do
    "/articles/#{doc_id}"
  end
end
```

## Result Structure and Format

### Standard Result Format

TantivyEx returns results in a consistent format:

```elixir
# Single result tuple format
{score, document_fields} = result

# Where:
score = 1.2345  # Float relevance score
document_fields = %{
  "title" => "Document Title",
  "content" => "Full document content...",
  "metadata" => "Additional data"
}

# Multiple results
results = [
  {1.5, %{"title" => "Most Relevant", "content" => "..."}},
  {1.2, %{"title" => "Second Most", "content" => "..."}},
  {0.9, %{"title" => "Third Most", "content" => "..."}}
]
```

### Enhanced Result Format

Create enhanced result structures for your application:

```elixir
defmodule MyApp.SearchResult do
  defstruct [
    :score,
    :normalized_score,
    :doc_id,
    :title,
    :content,
    :author,
    :published_at,
    :highlights,
    :snippet,
    :url,
    :metadata
  ]

  def from_tantivy_result({score, document}, max_score \\ nil) do
    %__MODULE__{
      score: score,
      normalized_score: normalize_score(score, max_score),
      title: document["title"],
      content: document["content"],
      author: document["author"],
      published_at: parse_published_date(document["published_at"]),
      url: build_url(document),
      metadata: extract_metadata(document)
    }
  end

  defp normalize_score(score, nil), do: score
  defp normalize_score(score, max_score) when max_score > 0 do
    Float.round(score / max_score * 100, 2)
  end
  defp normalize_score(_, _), do: 0.0

  defp parse_published_date(date_string) when is_binary(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end
  defp parse_published_date(_), do: nil

  defp build_url(%{"id" => id, "type" => "article"}), do: "/articles/#{id}"
  defp build_url(%{"id" => id, "type" => "product"}), do: "/products/#{id}"
  defp build_url(%{"id" => id}), do: "/documents/#{id}"
  defp build_url(_), do: nil

  defp extract_metadata(document) do
    document
    |> Map.take(["category", "tags", "word_count", "reading_time"])
    |> Map.reject(fn {_, v} -> is_nil(v) end)
  end
end
```

### JSON Serialization

Convert results to JSON for API responses:

```elixir
defmodule MyApp.ResultSerializer do
  def to_json(results, options \\ []) do
    include_content = Keyword.get(options, :include_content, true)
    include_metadata = Keyword.get(options, :include_metadata, false)

    results
    |> Enum.map(&serialize_result(&1, include_content, include_metadata))
    |> Jason.encode!()
  end

  defp serialize_result({score, document}, include_content, include_metadata) do
    base_result = %{
      score: score,
      title: document["title"],
      author: document["author"],
      published_at: document["published_at"]
    }

    base_result
    |> maybe_add_content(document, include_content)
    |> maybe_add_metadata(document, include_metadata)
  end

  defp maybe_add_content(result, document, true) do
    Map.put(result, :content, document["content"])
  end
  defp maybe_add_content(result, _document, false), do: result

  defp maybe_add_metadata(result, document, true) do
    metadata = %{
      word_count: document["word_count"],
      category: document["category"],
      tags: document["tags"]
    }
    Map.put(result, :metadata, metadata)
  end
  defp maybe_add_metadata(result, _document, false), do: result
end
```

## Result Enhancement

### Score Normalization

Normalize scores for consistent comparison:

```elixir
defmodule MyApp.ScoreNormalizer do
  def normalize_results(results) do
    case results do
      [] -> []
      _ ->
        max_score = results |> Enum.map(fn {score, _} -> score end) |> Enum.max()
        Enum.map(results, &normalize_single_result(&1, max_score))
    end
  end

  defp normalize_single_result({score, document}, max_score) do
    normalized_score = if max_score > 0, do: score / max_score * 100, else: 0

    enhanced_document = Map.put(document, "normalized_score", normalized_score)
    {score, enhanced_document}
  end

  def categorize_by_relevance(results) do
    normalized_results = normalize_results(results)

    %{
      highly_relevant: filter_by_score_range(normalized_results, 80..100),
      moderately_relevant: filter_by_score_range(normalized_results, 50..79),
      somewhat_relevant: filter_by_score_range(normalized_results, 20..49),
      low_relevance: filter_by_score_range(normalized_results, 0..19)
    }
  end

  defp filter_by_score_range(results, range) do
    Enum.filter(results, fn {_score, document} ->
      normalized_score = document["normalized_score"]
      normalized_score in range
    end)
  end
end
```

### Content Enhancement

Add computed fields and enhance document data:

```elixir
defmodule MyApp.ContentEnhancer do
  def enhance_results(results, query_terms \\ []) do
    Enum.map(results, &enhance_single_result(&1, query_terms))
  end

  defp enhance_single_result({score, document}, query_terms) do
    enhanced_document = document
    |> add_reading_time()
    |> add_excerpt()
    |> add_term_frequency(query_terms)
    |> add_content_type()
    |> add_freshness_score()

    {score, enhanced_document}
  end

  defp add_reading_time(document) do
    content = Map.get(document, "content", "")
    word_count = content |> String.split() |> length()
    reading_time = max(1, div(word_count, 200))  # 200 WPM average

    Map.put(document, "reading_time_minutes", reading_time)
  end

  defp add_excerpt(document) do
    content = Map.get(document, "content", "")
    excerpt = content
    |> String.slice(0, 200)
    |> String.trim()
    |> Kernel.<>("...")

    Map.put(document, "excerpt", excerpt)
  end

  defp add_term_frequency(document, []), do: document
  defp add_term_frequency(document, query_terms) do
    content = Map.get(document, "content", "") |> String.downcase()
    title = Map.get(document, "title", "") |> String.downcase()

    term_frequency = query_terms
    |> Enum.map(fn term ->
      content_count = count_occurrences(content, String.downcase(term))
      title_count = count_occurrences(title, String.downcase(term))
      {term, %{content: content_count, title: title_count}}
    end)
    |> Map.new()

    Map.put(document, "term_frequency", term_frequency)
  end

  defp add_content_type(document) do
    title = Map.get(document, "title", "")
    content = Map.get(document, "content", "")

    content_type = cond do
      String.contains?(title, ["Tutorial", "Guide", "How to"]) -> "tutorial"
      String.contains?(title, ["Review", "Analysis"]) -> "review"
      String.length(content) < 500 -> "snippet"
      String.length(content) > 2000 -> "article"
      true -> "general"
    end

    Map.put(document, "content_type", content_type)
  end

  defp add_freshness_score(document) do
    case Map.get(document, "published_at") do
      nil -> Map.put(document, "freshness_score", 0.5)
      date_string ->
        case DateTime.from_iso8601(date_string) do
          {:ok, published_date, _} ->
            days_old = DateTime.diff(DateTime.utc_now(), published_date, :day)
            freshness_score = calculate_freshness_score(days_old)
            Map.put(document, "freshness_score", freshness_score)
          _ ->
            Map.put(document, "freshness_score", 0.5)
        end
    end
  end

  defp calculate_freshness_score(days_old) when days_old <= 7, do: 1.0
  defp calculate_freshness_score(days_old) when days_old <= 30, do: 0.8
  defp calculate_freshness_score(days_old) when days_old <= 90, do: 0.6
  defp calculate_freshness_score(days_old) when days_old <= 365, do: 0.4
  defp calculate_freshness_score(_), do: 0.2

  defp count_occurrences(text, term) do
    text
    |> String.split()
    |> Enum.count(&String.contains?(&1, term))
  end
end
```

## Highlighting and Snippets

### Basic Text Highlighting

Add highlighting to search results:

```elixir
defmodule MyApp.Highlighter do
  @default_options [
    highlight_tag_open: "<mark>",
    highlight_tag_close: "</mark>",
    max_highlights: 5,
    snippet_length: 200,
    snippet_separator: "..."
  ]

  def highlight_results(results, query_terms, options \\ []) do
    opts = Keyword.merge(@default_options, options)

    Enum.map(results, &highlight_single_result(&1, query_terms, opts))
  end

  defp highlight_single_result({score, document}, query_terms, opts) do
    highlighted_document = document
    |> highlight_field("title", query_terms, opts)
    |> highlight_field("content", query_terms, opts)
    |> add_snippet(query_terms, opts)

    {score, highlighted_document}
  end

  defp highlight_field(document, field_name, query_terms, opts) do
    case Map.get(document, field_name) do
      nil -> document
      field_value ->
        highlighted_value = apply_highlighting(field_value, query_terms, opts)
        highlighted_field_name = "#{field_name}_highlighted"
        Map.put(document, highlighted_field_name, highlighted_value)
    end
  end

  defp apply_highlighting(text, query_terms, opts) do
    open_tag = Keyword.get(opts, :highlight_tag_open)
    close_tag = Keyword.get(opts, :highlight_tag_close)
    max_highlights = Keyword.get(opts, :max_highlights)

    query_terms
    |> Enum.take(max_highlights)
    |> Enum.reduce(text, fn term, acc ->
      # Case-insensitive highlighting
      regex = ~r/\b#{Regex.escape(term)}\b/i
      String.replace(acc, regex, "#{open_tag}\\0#{close_tag}")
    end)
  end

  defp add_snippet(document, query_terms, opts) do
    content = Map.get(document, "content", "")
    snippet_length = Keyword.get(opts, :snippet_length)
    separator = Keyword.get(opts, :snippet_separator)

    snippet = case find_best_snippet(content, query_terms, snippet_length) do
      nil -> String.slice(content, 0, snippet_length) <> separator
      found_snippet -> found_snippet <> separator
    end

    Map.put(document, "snippet", snippet)
  end

  defp find_best_snippet(content, [], snippet_length) do
    String.slice(content, 0, snippet_length)
  end
  defp find_best_snippet(content, query_terms, snippet_length) do
    # Find the first occurrence of any query term
    term_positions = query_terms
    |> Enum.flat_map(fn term ->
      case :binary.matches(String.downcase(content), String.downcase(term)) do
        [] -> []
        matches -> matches
      end
    end)
    |> Enum.sort()

    case term_positions do
      [] -> String.slice(content, 0, snippet_length)
      [{start_pos, _} | _] ->
        # Start snippet a bit before the match for context
        snippet_start = max(0, start_pos - 50)
        String.slice(content, snippet_start, snippet_length)
    end
  end
end
```

### Advanced Snippet Generation

Create contextual snippets around matches:

```elixir
defmodule MyApp.AdvancedSnippets do
  def generate_smart_snippets(results, query_terms, options \\ []) do
    max_snippets = Keyword.get(options, :max_snippets, 3)
    snippet_length = Keyword.get(options, :snippet_length, 150)
    context_padding = Keyword.get(options, :context_padding, 30)

    Enum.map(results, fn {score, document} ->
      snippets = extract_snippets(
        document["content"],
        query_terms,
        max_snippets,
        snippet_length,
        context_padding
      )

      enhanced_document = Map.put(document, "snippets", snippets)
      {score, enhanced_document}
    end)
  end

  defp extract_snippets(content, query_terms, max_snippets, snippet_length, context_padding) do
    # Find all term positions
    term_positions = find_all_term_positions(content, query_terms)

    # Group nearby positions into clusters
    clusters = cluster_positions(term_positions, snippet_length)

    # Generate snippets for top clusters
    clusters
    |> Enum.take(max_snippets)
    |> Enum.map(&generate_snippet_for_cluster(content, &1, snippet_length, context_padding))
  end

  defp find_all_term_positions(content, query_terms) do
    downcase_content = String.downcase(content)

    query_terms
    |> Enum.flat_map(fn term ->
      term_lower = String.downcase(term)
      case :binary.matches(downcase_content, term_lower) do
        [] -> []
        matches ->
          Enum.map(matches, fn {pos, len} ->
            %{term: term, start: pos, end: pos + len, score: term_score(term)}
          end)
      end
    end)
    |> Enum.sort_by(& &1.start)
  end

  defp term_score(term) do
    # Longer terms get higher scores
    String.length(term) * 1.0
  end

  defp cluster_positions(positions, max_distance) do
    positions
    |> Enum.reduce([], fn pos, clusters ->
      case find_nearby_cluster(clusters, pos, max_distance) do
        nil -> [%{positions: [pos], start: pos.start, end: pos.end, score: pos.score} | clusters]
        cluster_index ->
          update_cluster(clusters, cluster_index, pos)
      end
    end)
    |> Enum.sort_by(& &1.score, :desc)
  end

  defp find_nearby_cluster(clusters, position, max_distance) do
    clusters
    |> Enum.with_index()
    |> Enum.find(fn {cluster, _index} ->
      abs(cluster.start - position.start) <= max_distance or
      abs(cluster.end - position.end) <= max_distance
    end)
    |> case do
      {_cluster, index} -> index
      nil -> nil
    end
  end

  defp update_cluster(clusters, index, position) do
    List.update_at(clusters, index, fn cluster ->
      %{
        positions: [position | cluster.positions],
        start: min(cluster.start, position.start),
        end: max(cluster.end, position.end),
        score: cluster.score + position.score
      }
    end)
  end

  defp generate_snippet_for_cluster(content, cluster, snippet_length, context_padding) do
    # Calculate snippet boundaries with context
    snippet_start = max(0, cluster.start - context_padding)
    snippet_end = min(String.length(content), cluster.end + context_padding)

    # Adjust to stay within snippet_length
    if snippet_end - snippet_start > snippet_length do
      middle = div(cluster.start + cluster.end, 2)
      half_length = div(snippet_length, 2)
      snippet_start = max(0, middle - half_length)
      snippet_end = min(String.length(content), snippet_start + snippet_length)
    end

    content
    |> String.slice(snippet_start, snippet_end - snippet_start)
    |> String.trim()
  end
end
```

## Pagination and Limiting

### Basic Pagination

Implement pagination for search results:

```elixir
defmodule MyApp.Paginator do
  def paginate_search(searcher, query, page, per_page) do
    # Calculate offset
    offset = (page - 1) * per_page
    limit = per_page

    # Get more results than needed to enable "has_more" detection
    fetch_limit = limit + 1

    case TantivyEx.Searcher.search(searcher, query, offset + fetch_limit) do
      {:ok, all_results} ->
        # Skip offset results and take only what we need
        page_results = all_results
        |> Enum.drop(offset)
        |> Enum.take(limit)

        has_more = length(all_results) > offset + limit

        {:ok, %{
          results: page_results,
          page: page,
          per_page: per_page,
          has_more: has_more,
          total_on_page: length(page_results)
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

### Advanced Pagination with Metadata

Create comprehensive pagination with full metadata:

```elixir
defmodule MyApp.AdvancedPaginator do
  def paginate_with_metadata(searcher, query, page, per_page, options \\ []) do
    include_total = Keyword.get(options, :include_total, false)
    max_results = Keyword.get(options, :max_results, 10_000)

    # Calculate pagination parameters
    offset = (page - 1) * per_page

    # Fetch results
    case fetch_paginated_results(searcher, query, offset, per_page, max_results) do
      {:ok, {results, total_count}} ->
        pagination_metadata = build_pagination_metadata(
          page, per_page, total_count, include_total
        )

        {:ok, %{
          results: results,
          pagination: pagination_metadata
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_paginated_results(searcher, query, offset, per_page, max_results) do
    # Fetch enough results to determine pagination
    fetch_limit = min(offset + per_page + 1, max_results)

    case TantivyEx.Searcher.search(searcher, query, fetch_limit) do
      {:ok, all_results} ->
        page_results = all_results
        |> Enum.drop(offset)
        |> Enum.take(per_page)

        total_available = length(all_results)
        {:ok, {page_results, total_available}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_pagination_metadata(page, per_page, total_count, include_total) do
    has_next = total_count > page * per_page
    has_prev = page > 1

    base_metadata = %{
      current_page: page,
      per_page: per_page,
      has_next_page: has_next,
      has_prev_page: has_prev,
      next_page: if(has_next, do: page + 1, else: nil),
      prev_page: if(has_prev, do: page - 1, else: nil)
    }

    if include_total do
      total_pages = if total_count > 0, do: ceil(total_count / per_page), else: 0

      Map.merge(base_metadata, %{
        total_count: total_count,
        total_pages: total_pages,
        is_first_page: page == 1,
        is_last_page: page >= total_pages
      })
    else
      base_metadata
    end
  end
end
```

### Cursor-Based Pagination

Implement efficient cursor-based pagination:

```elixir
defmodule MyApp.CursorPaginator do
  def paginate_with_cursor(searcher, query, cursor \\ nil, per_page \\ 20) do
    {offset, last_score} = decode_cursor(cursor)

    # Fetch more than needed to generate next cursor
    fetch_limit = offset + per_page + 1

    case TantivyEx.Searcher.search(searcher, query, fetch_limit) do
      {:ok, all_results} ->
        # Filter results after cursor if score-based filtering is needed
        filtered_results = if last_score do
          filter_after_score(all_results, last_score, offset)
        else
          Enum.drop(all_results, offset)
        end

        page_results = Enum.take(filtered_results, per_page)

        next_cursor = if length(filtered_results) > per_page do
          generate_next_cursor(page_results, offset + per_page)
        else
          nil
        end

        {:ok, %{
          results: page_results,
          next_cursor: next_cursor,
          has_more: !is_nil(next_cursor)
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_cursor(nil), do: {0, nil}
  defp decode_cursor(cursor) do
    case Base.decode64(cursor) do
      {:ok, decoded} ->
        case Jason.decode(decoded) do
          {:ok, %{"offset" => offset, "score" => score}} -> {offset, score}
          {:ok, %{"offset" => offset}} -> {offset, nil}
          _ -> {0, nil}
        end
      _ -> {0, nil}
    end
  end

  defp filter_after_score(results, last_score, offset) do
    results
    |> Enum.drop(offset)
    |> Enum.drop_while(fn {score, _doc} -> score >= last_score end)
  end

  defp generate_next_cursor(page_results, next_offset) do
    case List.last(page_results) do
      {last_score, _doc} ->
        cursor_data = %{offset: next_offset, score: last_score}
        cursor_data
        |> Jason.encode!()
        |> Base.encode64()
      _ -> nil
    end
  end
end
```

## Performance Optimization

### Lazy Result Loading

Implement lazy loading for large result sets:

```elixir
defmodule MyApp.LazyResults do
  defstruct [:searcher, :query, :batch_size, :current_offset, :total_loaded, :cache]

  def new(searcher, query, batch_size \\ 100) do
    %__MODULE__{
      searcher: searcher,
      query: query,
      batch_size: batch_size,
      current_offset: 0,
      total_loaded: 0,
      cache: []
    }
  end

  def take(lazy_results, count) do
    needed = count - length(lazy_results.cache)

    if needed > 0 do
      case load_more(lazy_results, needed) do
        {:ok, updated_lazy} ->
          {results, remaining_cache} = Enum.split(updated_lazy.cache, count)
          updated = %{updated_lazy | cache: remaining_cache}
          {:ok, results, updated}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {results, remaining_cache} = Enum.split(lazy_results.cache, count)
      updated = %{lazy_results | cache: remaining_cache}
      {:ok, results, updated}
    end
  end

  defp load_more(lazy_results, needed) do
    batch_count = max(1, div(needed, lazy_results.batch_size) + 1)
    fetch_size = batch_count * lazy_results.batch_size

    case TantivyEx.Searcher.search(
      lazy_results.searcher,
      lazy_results.query,
      lazy_results.current_offset + fetch_size
    ) do
      {:ok, all_results} ->
        new_results = all_results
        |> Enum.drop(lazy_results.current_offset)
        |> Enum.take(fetch_size)

        updated = %{lazy_results |
          cache: lazy_results.cache ++ new_results,
          current_offset: lazy_results.current_offset + length(new_results),
          total_loaded: lazy_results.total_loaded + length(new_results)
        }

        {:ok, updated}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def stream(lazy_results) do
    Stream.unfold(lazy_results, fn
      nil -> nil
      current_lazy ->
        case take(current_lazy, 1) do
          {:ok, [], _updated} -> nil
          {:ok, [result], updated} -> {result, updated}
          {:error, _} -> nil
        end
    end)
  end
end
```

### Result Caching

Implement intelligent result caching:

```elixir
defmodule MyApp.ResultCache do
  use GenServer

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_cached_results(query_hash, page, per_page) do
    cache_key = {query_hash, page, per_page}
    GenServer.call(__MODULE__, {:get, cache_key})
  end

  def cache_results(query_hash, page, per_page, results) do
    cache_key = {query_hash, page, per_page}
    GenServer.cast(__MODULE__, {:put, cache_key, results, :os.system_time(:second)})
  end

  def clear_cache do
    GenServer.cast(__MODULE__, :clear)
  end

  # Server implementation
  def init(opts) do
    max_size = Keyword.get(opts, :max_size, 1000)
    ttl_seconds = Keyword.get(opts, :ttl_seconds, 300)  # 5 minutes

    state = %{
      cache: %{},
      max_size: max_size,
      ttl_seconds: ttl_seconds
    }

    # Schedule periodic cleanup
    schedule_cleanup()

    {:ok, state}
  end

  def handle_call({:get, key}, _from, state) do
    case Map.get(state.cache, key) do
      {results, timestamp} ->
        if not_expired?(timestamp, state.ttl_seconds) do
          {:reply, {:ok, results}, state}
        else
          new_cache = Map.delete(state.cache, key)
          {:reply, :not_found, %{state | cache: new_cache}}
        end
      nil ->
        {:reply, :not_found, state}
    end
  end

  def handle_cast({:put, key, results, timestamp}, state) do
    new_cache = state.cache
    |> Map.put(key, {results, timestamp})
    |> maybe_evict_old_entries(state.max_size)

    {:noreply, %{state | cache: new_cache}}
  end

  def handle_cast(:clear, state) do
    {:noreply, %{state | cache: %{}}}
  end

  def handle_info(:cleanup, state) do
    current_time = :os.system_time(:second)

    new_cache = state.cache
    |> Enum.reject(fn {_key, {_results, timestamp}} ->
      current_time - timestamp > state.ttl_seconds
    end)
    |> Map.new()

    schedule_cleanup()
    {:noreply, %{state | cache: new_cache}}
  end

  defp not_expired?(timestamp, ttl_seconds) do
    :os.system_time(:second) - timestamp < ttl_seconds
  end

  defp maybe_evict_old_entries(cache, max_size) when map_size(cache) <= max_size do
    cache
  end
  defp maybe_evict_old_entries(cache, max_size) do
    # Remove oldest entries
    sorted_by_time = cache
    |> Enum.sort_by(fn {_key, {_results, timestamp}} -> timestamp end)

    keep_count = max_size - 1
    sorted_by_time
    |> Enum.take(-keep_count)
    |> Map.new()
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, 60_000)  # Clean up every minute
  end
end
```

## Advanced Processing

### Result Aggregation

Aggregate and analyze search results:

```elixir
defmodule MyApp.ResultAggregator do
  def aggregate_results(results, aggregation_fields) do
    base_stats = calculate_base_stats(results)

    field_aggregations = aggregation_fields
    |> Enum.into(%{}, fn field ->
      {field, aggregate_field(results, field)}
    end)

    %{
      statistics: base_stats,
      aggregations: field_aggregations
    }
  end

  defp calculate_base_stats(results) do
    scores = Enum.map(results, fn {score, _doc} -> score end)

    %{
      total_results: length(results),
      score_statistics: %{
        min: Enum.min(scores, fn -> 0 end),
        max: Enum.max(scores, fn -> 0 end),
        average: if(length(scores) > 0, do: Enum.sum(scores) / length(scores), else: 0),
        median: calculate_median(scores)
      }
    }
  end

  defp aggregate_field(results, field) do
    field_values = results
    |> Enum.map(fn {_score, doc} -> Map.get(doc, field) end)
    |> Enum.reject(&is_nil/1)

    %{
      total_values: length(field_values),
      unique_values: field_values |> Enum.uniq() |> length(),
      value_counts: count_values(field_values),
      top_values: top_values(field_values, 10)
    }
  end

  defp calculate_median([]), do: 0
  defp calculate_median(scores) do
    sorted = Enum.sort(scores)
    count = length(sorted)

    if rem(count, 2) == 0 do
      middle_right = div(count, 2)
      middle_left = middle_right - 1
      (Enum.at(sorted, middle_left) + Enum.at(sorted, middle_right)) / 2
    else
      Enum.at(sorted, div(count, 2))
    end
  end

  defp count_values(values) do
    Enum.reduce(values, %{}, fn value, acc ->
      Map.update(acc, value, 1, &(&1 + 1))
    end)
  end

  defp top_values(values, limit) do
    values
    |> count_values()
    |> Enum.sort_by(fn {_value, count} -> count end, :desc)
    |> Enum.take(limit)
  end
end
```

### Result Filtering and Sorting

Advanced filtering and custom sorting:

```elixir
defmodule MyApp.ResultProcessor do
  def filter_and_sort(results, filters \\ [], sort_options \\ []) do
    results
    |> apply_filters(filters)
    |> apply_custom_sorting(sort_options)
  end

  defp apply_filters(results, []), do: results
  defp apply_filters(results, filters) do
    Enum.filter(results, fn {_score, document} ->
      Enum.all?(filters, &apply_filter(&1, document))
    end)
  end

  defp apply_filter({:field_equals, field, value}, document) do
    Map.get(document, field) == value
  end

  defp apply_filter({:field_contains, field, substring}, document) do
    case Map.get(document, field) do
      nil -> false
      field_value when is_binary(field_value) ->
        String.contains?(String.downcase(field_value), String.downcase(substring))
      _ -> false
    end
  end

  defp apply_filter({:field_greater_than, field, value}, document) do
    case Map.get(document, field) do
      nil -> false
      field_value when is_number(field_value) -> field_value > value
      _ -> false
    end
  end

  defp apply_filter({:date_range, field, start_date, end_date}, document) do
    case Map.get(document, field) do
      nil -> false
      date_string ->
        case DateTime.from_iso8601(date_string) do
          {:ok, date, _} ->
            DateTime.compare(date, start_date) != :lt and
            DateTime.compare(date, end_date) != :gt
          _ -> false
        end
    end
  end

  defp apply_filter({:custom, filter_fun}, document) when is_function(filter_fun) do
    filter_fun.(document)
  end

  defp apply_custom_sorting(results, []), do: results
  defp apply_custom_sorting(results, sort_options) do
    sort_by = Keyword.get(sort_options, :sort_by, :score)
    direction = Keyword.get(sort_options, :direction, :desc)

    sorted = case sort_by do
      :score ->
        Enum.sort_by(results, fn {score, _doc} -> score end, direction)

      :date ->
        Enum.sort_by(results, fn {_score, doc} ->
          parse_date_for_sorting(doc["published_at"])
        end, direction)

      field when is_atom(field) ->
        field_string = Atom.to_string(field)
        Enum.sort_by(results, fn {_score, doc} ->
          Map.get(doc, field_string, "")
        end, direction)

      {:custom, sort_fun} when is_function(sort_fun) ->
        Enum.sort_by(results, sort_fun, direction)
    end

    sorted
  end

  defp parse_date_for_sorting(nil), do: ~U[1970-01-01 00:00:00Z]
  defp parse_date_for_sorting(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _} -> datetime
      _ -> ~U[1970-01-01 00:00:00Z]
    end
  end
end
```

## Result Analytics

### Search Analytics

Track and analyze search result patterns:

```elixir
defmodule MyApp.SearchAnalytics do
  def analyze_search_session(search_results, query_info) do
    %{
      query_analysis: analyze_query(query_info),
      result_analysis: analyze_results(search_results),
      relevance_analysis: analyze_relevance(search_results),
      performance_metrics: calculate_performance_metrics(search_results, query_info)
    }
  end

  defp analyze_query(query_info) do
    query_text = Map.get(query_info, :text, "")

    %{
      query_length: String.length(query_text),
      word_count: String.split(query_text) |> length(),
      has_special_chars: String.match?(query_text, ~r/[^a-zA-Z0-9\s]/),
      query_type: determine_query_type(query_text),
      complexity_score: calculate_query_complexity(query_text)
    }
  end

  defp analyze_results(results) do
    scores = Enum.map(results, fn {score, _doc} -> score end)

    %{
      total_results: length(results),
      score_distribution: analyze_score_distribution(scores),
      content_types: analyze_content_types(results),
      date_distribution: analyze_date_distribution(results)
    }
  end

  defp analyze_relevance(results) do
    scores = Enum.map(results, fn {score, _doc} -> score end)

    case scores do
      [] -> %{relevance_quality: "no_results"}
      _ ->
        max_score = Enum.max(scores)
        min_score = Enum.min(scores)
        score_range = max_score - min_score

        %{
          relevance_quality: determine_relevance_quality(scores),
          score_spread: score_range,
          top_result_dominance: if(length(scores) > 1, do: max_score / Enum.at(scores, 1), else: 1.0)
        }
    end
  end

  defp calculate_performance_metrics(results, query_info) do
    search_time = Map.get(query_info, :search_time_ms, 0)

    %{
      search_time_ms: search_time,
      results_per_ms: if(search_time > 0, do: length(results) / search_time, else: 0),
      efficiency_score: calculate_efficiency_score(length(results), search_time)
    }
  end

  defp determine_query_type(query_text) do
    cond do
      String.contains?(query_text, ["\"", "'"]) -> :phrase_query
      String.contains?(query_text, ["AND", "OR", "NOT"]) -> :boolean_query
      String.contains?(query_text, "*") -> :wildcard_query
      String.split(query_text) |> length() == 1 -> :single_term
      true -> :multi_term
    end
  end

  defp calculate_query_complexity(query_text) do
    base_score = String.split(query_text) |> length()

    modifiers = [
      {~r/["']/, 2},      # Phrases
      {~r/AND|OR|NOT/i, 3}, # Boolean operators
      {~r/\*/, 1},        # Wildcards
      {~r/\d+/, 1}        # Numbers
    ]

    modifier_score = modifiers
    |> Enum.reduce(0, fn {regex, score}, acc ->
      if String.match?(query_text, regex), do: acc + score, else: acc
    end)

    base_score + modifier_score
  end

  defp analyze_score_distribution(scores) do
    case scores do
      [] -> %{distribution_type: "empty"}
      _ ->
        sorted_scores = Enum.sort(scores, :desc)
        max_score = List.first(sorted_scores)
        min_score = List.last(sorted_scores)

        %{
          distribution_type: determine_distribution_type(sorted_scores),
          score_gap: max_score - min_score,
          uniformity: calculate_uniformity(sorted_scores)
        }
    end
  end

  defp determine_distribution_type(sorted_scores) do
    if length(sorted_scores) < 2 do
      "single"
    else
      first_score = List.first(sorted_scores)
      second_score = Enum.at(sorted_scores, 1)

      if first_score > second_score * 1.5 do
        "dominant_leader"
      else
        "competitive"
      end
    end
  end

  defp calculate_uniformity(scores) do
    if length(scores) < 2 do
      1.0
    else
      mean = Enum.sum(scores) / length(scores)
      variance = scores
      |> Enum.map(fn score -> :math.pow(score - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(scores))

      # Lower variance means higher uniformity
      1.0 / (1.0 + variance)
    end
  end

  defp analyze_content_types(results) do
    results
    |> Enum.map(fn {_score, doc} -> Map.get(doc, "content_type", "unknown") end)
    |> Enum.reduce(%{}, fn type, acc ->
      Map.update(acc, type, 1, &(&1 + 1))
    end)
  end

  defp analyze_date_distribution(results) do
    results
    |> Enum.map(fn {_score, doc} -> Map.get(doc, "published_at") end)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&parse_date_for_analysis/1)
    |> Enum.reject(&is_nil/1)
    |> group_by_time_period()
  end

  defp parse_date_for_analysis(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp group_by_time_period(dates) do
    now = DateTime.utc_now()

    Enum.reduce(dates, %{recent: 0, medium: 0, old: 0}, fn date, acc ->
      days_ago = DateTime.diff(now, date, :day)

      cond do
        days_ago <= 30 -> Map.update!(acc, :recent, &(&1 + 1))
        days_ago <= 365 -> Map.update!(acc, :medium, &(&1 + 1))
        true -> Map.update!(acc, :old, &(&1 + 1))
      end
    end)
  end

  defp determine_relevance_quality(scores) do
    if length(scores) == 0 do
      "no_results"
    else
      max_score = Enum.max(scores)
      avg_score = Enum.sum(scores) / length(scores)

      cond do
        max_score > 2.0 and avg_score > 0.8 -> "excellent"
        max_score > 1.5 and avg_score > 0.5 -> "good"
        max_score > 1.0 and avg_score > 0.3 -> "fair"
        true -> "poor"
      end
    end
  end

  defp calculate_efficiency_score(result_count, search_time_ms) do
    cond do
      search_time_ms <= 0 -> 100
      search_time_ms < 50 -> 95
      search_time_ms < 100 -> 85
      search_time_ms < 200 -> 75
      search_time_ms < 500 -> 60
      true -> 40
    end
  end
end
```

## Best Practices

### Performance Best Practices

1. **Limit Result Sets**: Always set reasonable limits on result counts
2. **Use Pagination**: Implement pagination for better user experience and performance
3. **Cache Strategically**: Cache frequent searches and expensive result processing
4. **Process Incrementally**: Use streaming and lazy loading for large result sets

```elixir
# Good: Reasonable limits and pagination
{:ok, results} = TantivyEx.Searcher.search(searcher, query, 20)  # Small page size

# Good: Cached processing
defmodule MyApp.CachedSearch do
  def search_with_cache(query_text, page, per_page) do
    cache_key = :crypto.hash(:md5, "#{query_text}:#{page}:#{per_page}")

    case MyApp.ResultCache.get_cached_results(cache_key, page, per_page) do
      {:ok, cached_results} -> {:ok, cached_results}
      :not_found ->
        case perform_search(query_text, page, per_page) do
          {:ok, results} ->
            MyApp.ResultCache.cache_results(cache_key, page, per_page, results)
            {:ok, results}
          error -> error
        end
    end
  end
end
```

### Result Quality Best Practices

1. **Validate Result Data**: Ensure document fields are properly formatted
2. **Enhance Contextually**: Add relevant metadata and computed fields
3. **Normalize Scores**: Provide meaningful score comparisons
4. **Handle Edge Cases**: Gracefully handle missing data and errors

```elixir
# Good: Comprehensive result validation
defmodule MyApp.ResultValidator do
  def validate_and_enhance_results(results, schema) do
    results
    |> Enum.map(&validate_single_result(&1, schema))
    |> Enum.reject(&match?({:error, _}, &1))
    |> Enum.map(fn {:ok, result} -> result end)
  end

  defp validate_single_result({score, document}, schema) do
    with :ok <- validate_score(score),
         {:ok, validated_doc} <- validate_document_fields(document, schema) do
      {:ok, {score, validated_doc}}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
```

### User Experience Best Practices

1. **Provide Clear Feedback**: Show loading states and result counts
2. **Highlight Relevance**: Use highlighting and snippets effectively
3. **Enable Discovery**: Include related content and suggestions
4. **Optimize for Mobile**: Ensure results display well on all devices

```elixir
# Good: Rich result metadata for UX
def enhance_for_display(results, query_terms) do
  Enum.map(results, fn {score, document} ->
    %{
      id: document["id"],
      title: document["title"],
      snippet: generate_snippet(document["content"], query_terms),
      highlights: generate_highlights(document, query_terms),
      metadata: %{
        author: document["author"],
        published_date: format_date_for_display(document["published_at"]),
        reading_time: calculate_reading_time(document["content"]),
        relevance_percent: normalize_score_to_percentage(score)
      },
      url: build_result_url(document)
    }
  end)
end
```

## Troubleshooting

### Common Issues

#### Empty Results

```elixir
# Problem: No results returned for valid query
case TantivyEx.Searcher.search(searcher, query, 10) do
  {:ok, []} ->
    # Debug steps:
    # 1. Check if index has documents
    # 2. Verify query syntax
    # 3. Check field names in query
    # 4. Verify index schema matches document structure
    debug_empty_results(searcher, query)
  {:ok, results} -> process_results(results)
end

defp debug_empty_results(searcher, query) do
  # Check index document count
  case get_document_count(searcher) do
    0 -> {:error, "Index is empty"}
    count ->
      Logger.warning("Index has #{count} documents but query returned no results")
      {:error, "No matching documents"}
  end
end
```

#### Performance Issues

```elixir
# Problem: Slow result processing
def optimize_result_processing(results) do
  # Solution: Process in batches and use parallel processing
  results
  |> Stream.chunk_every(100)  # Process in batches
  |> Task.async_stream(&process_result_batch/1, max_concurrency: 4)
  |> Enum.reduce([], fn {:ok, batch_results}, acc -> acc ++ batch_results end)
end

defp process_result_batch(batch) do
  # Lighter processing per batch
  Enum.map(batch, &minimal_result_processing/1)
end
```

#### Memory Issues with Large Results

```elixir
# Problem: Running out of memory with large result sets
def handle_large_results(searcher, query, total_needed) do
  # Solution: Stream processing
  stream_results(searcher, query, total_needed)
  |> Stream.map(&process_single_result/1)
  |> Stream.chunk_every(1000)  # Process in chunks
  |> Enum.to_list()
end

defp stream_results(searcher, query, total_needed) do
  Stream.unfold({searcher, query, 0, 100}, fn
    {searcher, query, offset, batch_size} when offset < total_needed ->
      case TantivyEx.Searcher.search(searcher, query, offset + batch_size) do
        {:ok, all_results} ->
          batch = all_results |> Enum.drop(offset) |> Enum.take(batch_size)
          if length(batch) > 0 do
            {batch, {searcher, query, offset + batch_size, batch_size}}
          else
            nil
          end
        _ -> nil
      end
    _ -> nil
  end)
  |> Stream.flat_map(& &1)
end
```

### Debugging Tools

```elixir
defmodule MyApp.SearchDebugger do
  def debug_search_results(searcher, query, limit) do
    start_time = :os.system_time(:millisecond)

    result = TantivyEx.Searcher.search(searcher, query, limit)

    end_time = :os.system_time(:millisecond)
    search_time = end_time - start_time

    case result do
      {:ok, results} ->
        debug_info = %{
          search_time_ms: search_time,
          result_count: length(results),
          score_range: calculate_score_range(results),
          sample_results: Enum.take(results, 3)
        }

        Logger.info("Search Debug: #{inspect(debug_info)}")
        {:ok, results}

      {:error, reason} ->
        Logger.error("Search failed: #{reason} (took #{search_time}ms)")
        {:error, reason}
    end
  end

  defp calculate_score_range([]), do: {0, 0}
  defp calculate_score_range(results) do
    scores = Enum.map(results, fn {score, _doc} -> score end)
    {Enum.min(scores), Enum.max(scores)}
  end
end
```

This comprehensive search results guide provides everything you need to effectively process, enhance, and optimize search results in TantivyEx, from basic result handling to advanced analytics and performance optimization.
