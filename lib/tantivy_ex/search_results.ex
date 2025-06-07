defmodule TantivyEx.SearchResults do
  @moduledoc """
  Comprehensive search results processing and formatting for TantivyEx.

  This module provides advanced result processing capabilities including:
  - Result formatting and normalization
  - Highlighting and snippets
  - Metadata enhancement
  - Pagination support
  - Performance metrics
  - Result aggregation and faceting
  - Schema-aware field mapping in results

  ## Features

  ### Result Processing
  - Schema-aware field type conversion
  - Automatic highlighting of search terms
  - Snippet extraction with context
  - Score normalization and ranking
  - Metadata enrichment

  ### Performance Optimization
  - Lazy loading of document content
  - Configurable result processing
  - Memory-efficient handling of large result sets
  - Streaming support for bulk operations

  ### Analytics Support
  - Search performance metrics
  - Result quality analysis
  - Click-through tracking preparation
  - Query analysis helpers

  ## Usage Examples

      # Basic result processing
      {:ok, results} = TantivyEx.Searcher.search(searcher, query, 10)
      {:ok, processed} = SearchResults.process(results, schema, options)

      # Advanced processing with highlighting
      options = [
        highlight: true,
        snippet_length: 200,
        include_metadata: true,
        normalize_scores: true
      ]
      {:ok, enhanced_results} = SearchResults.enhance(results, schema, query, options)

      # Pagination with metadata
      {:ok, page_results} = SearchResults.paginate(results, page: 2, per_page: 20)

      # Result aggregation
      {:ok, aggregated} = SearchResults.aggregate(results, [:category, :price_range])
  """

  alias TantivyEx.{Schema, Query}

  @type search_result :: %{
          score: float(),
          doc_id: pos_integer(),
          document: map()
        }

  @type processed_result :: %{
          score: float(),
          normalized_score: float(),
          doc_id: pos_integer(),
          document: map(),
          highlights: map(),
          snippet: String.t(),
          metadata: map()
        }

  @type result_options :: [
          highlight: boolean(),
          snippet_length: pos_integer(),
          include_metadata: boolean(),
          normalize_scores: boolean(),
          max_highlights: pos_integer(),
          highlight_tags: {String.t(), String.t()},
          schema_validation: boolean()
        ]

  @type pagination_options :: [
          page: pos_integer(),
          per_page: pos_integer(),
          include_total: boolean()
        ]

  @default_options [
    highlight: false,
    snippet_length: 200,
    include_metadata: false,
    normalize_scores: false,
    max_highlights: 5,
    highlight_tags: {"<mark>", "</mark>"},
    schema_validation: true
  ]

  @doc """
  Processes raw search results with schema-aware field mapping and type conversion.

  This is the core result processing function that normalizes field types according
  to the schema definition and ensures consistent result format.

  ## Parameters

  - `results`: List of raw search results from Searcher
  - `schema`: Schema for field type validation and conversion
  - `options`: Processing options (optional)

  ## Examples

      iex> {:ok, results} = TantivyEx.Searcher.search(searcher, query, 10)
      iex> {:ok, processed} = SearchResults.process(results, schema)
      iex> processed |> hd() |> Map.keys()
      ["score", "doc_id", "title", "content", "price", "published_at"]
  """
  @spec process([search_result()], Schema.t(), result_options()) ::
          {:ok, [map()]} | {:error, String.t()}
  def process(results, schema, options \\ [])

  def process(_results, nil, _options) do
    {:error, "Failed to process results: Schema cannot be nil"}
  end

  def process(results, schema, options) do
    opts = Keyword.merge(@default_options, options)

    try do
      processed_results =
        results
        |> Enum.map(&normalize_result(&1, schema, opts))
        |> Enum.map(&convert_field_types(&1, schema, opts))
        |> maybe_normalize_scores(opts)

      {:ok, processed_results}
    rescue
      e -> {:error, "Failed to process results: #{inspect(e)}"}
    end
  end

  @doc """
  Enhances search results with highlighting, snippets, and metadata.

  This function provides advanced result enhancement including search term highlighting,
  snippet extraction, and metadata enrichment.

  ## Parameters

  - `results`: List of search results
  - `schema`: Schema for field processing
  - `query`: Original search query for highlighting
  - `options`: Enhancement options

  ## Examples

      iex> options = [highlight: true, snippet_length: 150, include_metadata: true]
      iex> {:ok, enhanced} = SearchResults.enhance(results, schema, query, options)
      iex> enhanced |> hd() |> Map.get("highlights")
      %{"title" => ["Introduction to <mark>Elixir</mark>"], "content" => ["Learn <mark>Elixir</mark> programming"]}
  """
  @spec enhance([search_result()], Schema.t(), Query.t() | String.t(), result_options()) ::
          {:ok, [processed_result()]} | {:error, String.t()}
  def enhance(results, schema, query, options \\ []) do
    opts = Keyword.merge(@default_options, options)

    with {:ok, processed_results} <- process(results, schema, opts),
         {:ok, query_terms} <- extract_query_terms_private(query, schema) do
      enhanced_results =
        processed_results
        |> maybe_add_highlights(query_terms, opts)
        |> maybe_add_snippets(query_terms, opts)
        |> maybe_add_metadata(opts)

      {:ok, enhanced_results}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Paginates search results with metadata about pagination state.

  ## Parameters

  - `results`: List of search results
  - `options`: Pagination options

  ## Examples

      iex> {:ok, page_data} = SearchResults.paginate(results, page: 2, per_page: 10)
      iex> page_data.items |> length()
      10
      iex> page_data.metadata
      %{current_page: 2, per_page: 10, total_pages: 5, has_next: true, has_prev: true}
  """
  @spec paginate([map()], pagination_options()) :: {:ok, map()} | {:error, String.t()}
  def paginate(results, options \\ []) do
    page = Keyword.get(options, :page, 1)
    per_page = Keyword.get(options, :per_page, 20)
    include_total = Keyword.get(options, :include_total, true)

    if page < 1 or per_page < 1 do
      {:error, "Page and per_page must be positive integers"}
    else
      total_count = length(results)
      total_pages = ceil(total_count / per_page)
      start_index = (page - 1) * per_page

      items =
        if start_index < total_count do
          Enum.slice(results, start_index, per_page)
        else
          []
        end

      metadata = %{
        current_page: page,
        per_page: per_page,
        total_pages: total_pages,
        has_next: page < total_pages,
        has_prev: page > 1,
        start_index: start_index + 1,
        end_index: min(start_index + length(items), total_count)
      }

      metadata =
        if include_total do
          Map.put(metadata, :total_count, total_count)
        else
          metadata
        end

      result = %{
        items: items,
        metadata: metadata
      }

      {:ok, result}
    end
  end

  @doc """
  Aggregates search results by specified fields to generate facets.

  ## Parameters

  - `results`: List of search results
  - `facet_fields`: List of field names to aggregate by

  ## Examples

      iex> {:ok, facets} = SearchResults.aggregate(results, ["category", "price_range"])
      iex> facets
      %{
        "category" => %{"books" => 15, "electronics" => 8, "clothing" => 12},
        "price_range" => %{"0-25" => 10, "25-50" => 15, "50+" => 10}
      }
  """
  @spec aggregate([map()], [String.t()]) :: {:ok, map()} | {:error, String.t()}
  def aggregate(results, facet_fields) when is_list(facet_fields) do
    try do
      facets =
        facet_fields
        |> Enum.reduce(%{}, fn field_name, acc ->
          field_values = extract_field_values(results, field_name)
          field_counts = Enum.frequencies(field_values)
          Map.put(acc, field_name, field_counts)
        end)

      {:ok, facets}
    rescue
      e -> {:error, "Failed to aggregate results: #{inspect(e)}"}
    end
  end

  @doc """
  Formats search results for API responses with consistent structure.

  ## Parameters

  - `results`: Processed search results
  - `options`: Formatting options

  ## Examples

      iex> {:ok, api_response} = SearchResults.format_for_api(results, query: "elixir")
      iex> api_response
      %{
        "results" => [...],
        "metadata" => %{
          "query" => "elixir",
          "total_count" => 45,
          "execution_time_ms" => 12,
          "max_score" => 1.0
        }
      }
  """
  @spec format_for_api([map()], keyword()) :: {:ok, map()} | {:error, String.t()}
  def format_for_api(results, options \\ []) do
    try do
      metadata = %{
        total_count: length(results),
        max_score: calculate_max_score(results),
        min_score: calculate_min_score(results),
        avg_score: calculate_avg_score(results)
      }

      # Add optional metadata
      metadata =
        options
        |> Enum.reduce(metadata, fn {key, value}, acc ->
          case key do
            :query -> Map.put(acc, :query, value)
            :execution_time_ms -> Map.put(acc, :execution_time_ms, value)
            :search_type -> Map.put(acc, :search_type, value)
            _ -> acc
          end
        end)

      response = %{
        results: results,
        metadata: metadata
      }

      {:ok, response}
    rescue
      e -> {:error, "Failed to format results: #{inspect(e)}"}
    end
  end

  @doc """
  Extracts and analyzes query performance metrics from search results.

  ## Parameters

  - `results`: Search results
  - `execution_time`: Search execution time in milliseconds

  ## Examples

      iex> metrics = SearchResults.analyze_performance(results, 15)
      iex> metrics
      %{
        result_count: 25,
        execution_time_ms: 15,
        avg_score: 0.85,
        score_distribution: %{high: 5, medium: 15, low: 5},
        recommendations: ["Consider query optimization for better scores"]
      }
  """
  @spec analyze_performance([map()], non_neg_integer()) :: map()
  def analyze_performance(results, execution_time_ms) do
    result_count = length(results)
    scores = Enum.map(results, &Map.get(&1, "score", 0.0))

    avg_score =
      if result_count > 0 do
        Enum.sum(scores) / result_count
      else
        0.0
      end

    max_score = Enum.max(scores, fn -> 0.0 end)
    min_score = Enum.min(scores, fn -> 0.0 end)

    score_distribution = categorize_scores(scores)

    recommendations =
      generate_performance_recommendations(avg_score, execution_time_ms, result_count)

    %{
      result_count: result_count,
      execution_time_ms: execution_time_ms,
      avg_score: Float.round(avg_score, 3),
      max_score: max_score,
      min_score: min_score,
      score_distribution: score_distribution,
      recommendations: recommendations
    }
  end

  # Public query term extraction function
  @doc """
  Extracts query terms from a query string or Query object.

  ## Parameters

  - `query`: The query string or Query object to extract terms from
  - `schema`: The schema to use for term extraction

  ## Returns

  - `{:ok, terms}` where terms is a list of extracted terms
  - `{:error, reason}` if extraction fails

  ## Examples

      {:ok, terms} = SearchResults.extract_query_terms("hello world", schema)
      # Returns: {:ok, ["hello", "world"]}

      {:ok, terms} = SearchResults.extract_query_terms(query_object, schema)
      # Returns: {:ok, ["extracted", "terms"]}
  """
  @spec extract_query_terms(String.t() | term(), term()) ::
          {:ok, list(String.t())} | {:error, String.t()}
  def extract_query_terms(query, schema) do
    extract_query_terms_private(query, schema)
  end

  # Private helper functions

  defp normalize_result(result, _schema, _opts) do
    # Ensure consistent result structure
    %{
      "score" => Map.get(result, "score", 0.0),
      "doc_id" => Map.get(result, "doc_id", 0)
    }
    |> Map.merge(Map.drop(result, ["score", "doc_id"]))
  end

  defp convert_field_types(result, schema, opts) do
    if Keyword.get(opts, :schema_validation, true) do
      # Apply schema-based type conversion for each field
      Enum.reduce(result, %{}, fn {field_name, value}, acc ->
        converted_value = convert_field_value(value, field_name, schema)
        Map.put(acc, field_name, converted_value)
      end)
    else
      result
    end
  end

  defp convert_field_value(value, field_name, schema) do
    # Skip meta fields
    if field_name in ["score", "doc_id"] do
      value
    else
      case Schema.get_field_type(schema, field_name) do
        {:ok, field_type} -> apply_type_conversion(value, field_type)
        # Field not in schema, keep as-is
        {:error, _} -> value
      end
    end
  end

  defp apply_type_conversion(value, field_type) do
    case field_type do
      "text" -> ensure_string(value)
      "u64" -> ensure_positive_integer(value)
      "i64" -> ensure_integer(value)
      "f64" -> ensure_float(value)
      "bool" -> ensure_boolean(value)
      "date" -> ensure_datetime(value)
      "facet" -> ensure_string(value)
      # Base64 encoded
      "bytes" -> ensure_string(value)
      "json" -> ensure_valid_json(value)
      "ip_addr" -> ensure_string(value)
      _ -> value
    end
  end

  defp ensure_string(value) when is_binary(value), do: value
  defp ensure_string(value), do: to_string(value)

  defp ensure_positive_integer(value) when is_integer(value) and value >= 0, do: value

  defp ensure_positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= 0 -> int
      _ -> 0
    end
  end

  defp ensure_positive_integer(_), do: 0

  defp ensure_integer(value) when is_integer(value), do: value

  defp ensure_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> 0
    end
  end

  defp ensure_integer(_), do: 0

  defp ensure_float(value) when is_float(value), do: value
  defp ensure_float(value) when is_integer(value), do: value / 1

  defp ensure_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> float
      _ -> 0.0
    end
  end

  defp ensure_float(_), do: 0.0

  defp ensure_boolean(value) when is_boolean(value), do: value

  defp ensure_boolean(value) when is_binary(value) do
    String.downcase(value) in ["true", "1", "yes", "on"]
  end

  defp ensure_boolean(value) when is_integer(value), do: value != 0
  defp ensure_boolean(_), do: false

  defp ensure_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> datetime
      # Keep original if parsing fails
      _ -> value
    end
  end

  defp ensure_datetime(value), do: value

  defp ensure_valid_json(value) when is_map(value), do: value
  defp ensure_valid_json(value) when is_list(value), do: value

  defp ensure_valid_json(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, decoded} -> decoded
      _ -> value
    end
  end

  defp ensure_valid_json(value), do: value

  defp maybe_normalize_scores(results, opts) do
    if Keyword.get(opts, :normalize_scores, false) do
      scores = Enum.map(results, &Map.get(&1, "score", 0.0))
      max_score = Enum.max(scores, fn -> 1.0 end)

      if max_score > 0 do
        Enum.map(results, fn result ->
          normalized_score = Map.get(result, "score", 0.0) / max_score
          Map.put(result, "normalized_score", Float.round(normalized_score, 4))
        end)
      else
        results
      end
    else
      results
    end
  end

  defp extract_query_terms_private(query, _schema) when is_binary(query) do
    # Simple term extraction from string query
    terms =
      query
      |> String.downcase()
      |> String.replace(~r/[^\w\s]/, " ")
      |> String.split()
      |> Enum.reject(&(&1 in ["and", "or", "not", "the", "a", "an", "in", "on", "at"]))
      |> Enum.uniq()
      |> Enum.sort()

    {:ok, terms}
  end

  defp extract_query_terms_private(query, schema) do
    # For Query objects, use the NIF to extract terms
    case TantivyEx.Native.query_extract_terms(query, schema) do
      terms when is_list(terms) -> {:ok, terms}
      error -> {:error, "Failed to extract query terms: #{inspect(error)}"}
    end
  end

  defp maybe_add_highlights(results, query_terms, opts) do
    if Keyword.get(opts, :highlight, false) and not Enum.empty?(query_terms) do
      max_highlights = Keyword.get(opts, :max_highlights, 5)
      {start_tag, end_tag} = Keyword.get(opts, :highlight_tags, {"<mark>", "</mark>"})

      Enum.map(results, fn result ->
        highlights =
          generate_highlights(result, query_terms, max_highlights, {start_tag, end_tag})

        Map.put(result, "highlights", highlights)
      end)
    else
      results
    end
  end

  defp maybe_add_snippets(results, query_terms, opts) do
    snippet_length = Keyword.get(opts, :snippet_length, 200)

    if snippet_length > 0 and not Enum.empty?(query_terms) do
      Enum.map(results, fn result ->
        snippet = generate_snippet(result, query_terms, snippet_length)
        Map.put(result, "snippet", snippet)
      end)
    else
      results
    end
  end

  defp maybe_add_metadata(results, opts) do
    if Keyword.get(opts, :include_metadata, false) do
      Enum.with_index(results, 1)
      |> Enum.map(fn {result, index} ->
        metadata = %{
          "position" => index,
          "relevance_tier" => calculate_relevance_tier(Map.get(result, "score", 0.0)),
          # Exclude score and doc_id
          "field_count" => map_size(result) - 2
        }

        Map.put(result, "metadata", metadata)
      end)
    else
      results
    end
  end

  defp generate_highlights(result, query_terms, max_highlights, {start_tag, end_tag}) do
    text_fields = ["title", "content", "description", "body", "summary"]

    text_fields
    |> Enum.reduce(%{}, fn field_name, acc ->
      if Map.has_key?(result, field_name) do
        field_value = Map.get(result, field_name, "")

        if is_binary(field_value) do
          highlighted_passages =
            extract_highlighted_passages(
              field_value,
              query_terms,
              max_highlights,
              {start_tag, end_tag}
            )

          if not Enum.empty?(highlighted_passages) do
            Map.put(acc, field_name, highlighted_passages)
          else
            acc
          end
        else
          acc
        end
      else
        acc
      end
    end)
  end

  defp extract_highlighted_passages(text, query_terms, max_highlights, {start_tag, end_tag}) do
    # Find positions of query terms in text
    term_positions =
      query_terms
      |> Enum.flat_map(fn term ->
        find_term_positions(String.downcase(text), String.downcase(term))
      end)
      |> Enum.sort()
      |> Enum.take(max_highlights)

    # Extract passages around term positions
    term_positions
    |> Enum.map(fn position ->
      extract_passage_around_position(text, position, 50, query_terms, {start_tag, end_tag})
    end)
    |> Enum.uniq()
  end

  defp find_term_positions(text, term) do
    find_term_positions(text, term, 0, [])
  end

  defp find_term_positions(text, term, start_pos, positions) do
    remaining_text = String.slice(text, start_pos..-1//1)

    case String.first(remaining_text) do
      nil ->
        Enum.reverse(positions)

      _ ->
        case :binary.match(text, term, scope: {start_pos, byte_size(text) - start_pos}) do
          {pos, _len} -> find_term_positions(text, term, pos + 1, [pos | positions])
          :nomatch -> Enum.reverse(positions)
        end
    end
  end

  defp extract_passage_around_position(
         text,
         position,
         context_chars,
         query_terms,
         {start_tag, end_tag}
       ) do
    start_pos = max(0, position - context_chars)
    end_pos = min(String.length(text), position + context_chars)

    passage = String.slice(text, start_pos, end_pos - start_pos)

    # Highlight query terms in the passage
    Enum.reduce(query_terms, passage, fn term, acc ->
      regex = ~r/#{Regex.escape(term)}/i
      String.replace(acc, regex, "#{start_tag}\\0#{end_tag}")
    end)
  end

  defp generate_snippet(result, query_terms, snippet_length) do
    # Look for the best content field for snippet generation
    content_fields = ["content", "body", "description", "summary", "text"]

    content_field =
      content_fields
      |> Enum.find(fn field ->
        Map.has_key?(result, field) and is_binary(Map.get(result, field))
      end)

    case content_field do
      nil ->
        ""

      field_name ->
        content = Map.get(result, field_name, "")
        generate_snippet_from_content(content, query_terms, snippet_length)
    end
  end

  defp generate_snippet_from_content(content, query_terms, snippet_length) do
    if String.length(content) <= snippet_length do
      content
    else
      # Find the best position to start the snippet (around query terms)
      best_position = find_best_snippet_position(content, query_terms, snippet_length)

      start_pos = max(0, best_position - div(snippet_length, 2))
      snippet = String.slice(content, start_pos, snippet_length)

      # Clean up snippet boundaries (don't cut words)
      snippet = clean_snippet_boundaries(snippet)

      # Add ellipsis if needed
      snippet = if start_pos > 0, do: "..." <> snippet, else: snippet

      snippet =
        if start_pos + snippet_length < String.length(content),
          do: snippet <> "...",
          else: snippet

      snippet
    end
  end

  defp find_best_snippet_position(content, query_terms, _snippet_length) do
    # Find positions of all query terms
    term_positions =
      query_terms
      |> Enum.flat_map(fn term ->
        find_term_positions(String.downcase(content), String.downcase(term))
      end)

    case term_positions do
      # No terms found, start from beginning
      [] ->
        0

      positions ->
        # Use the first occurrence position
        Enum.min(positions)
    end
  end

  defp clean_snippet_boundaries(snippet) do
    # Remove partial words at the beginning and end
    snippet
    |> String.trim()
    |> remove_partial_word_at_start()
    |> remove_partial_word_at_end()
  end

  defp remove_partial_word_at_start(snippet) do
    case Regex.run(~r/^\S*\s+(.*)/, snippet, capture: :all_but_first) do
      [cleaned] -> cleaned
      _ -> snippet
    end
  end

  defp remove_partial_word_at_end(snippet) do
    case Regex.run(~r/(.*)\s+\S*$/, snippet, capture: :all_but_first) do
      [cleaned] -> cleaned
      _ -> snippet
    end
  end

  defp calculate_relevance_tier(score) when score >= 0.8, do: "high"
  defp calculate_relevance_tier(score) when score >= 0.5, do: "medium"
  defp calculate_relevance_tier(_score), do: "low"

  defp extract_field_values(results, field_name) do
    results
    |> Enum.map(&Map.get(&1, field_name))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&normalize_facet_value/1)
  end

  defp normalize_facet_value(value) when is_binary(value), do: value

  defp normalize_facet_value(value) when is_number(value) do
    cond do
      value < 25 -> "0-25"
      value < 50 -> "25-50"
      value < 100 -> "50-100"
      true -> "100+"
    end
  end

  defp normalize_facet_value(value), do: to_string(value)

  defp calculate_max_score(results) do
    results
    |> Enum.map(&Map.get(&1, "score", 0.0))
    |> Enum.max(fn -> 0.0 end)
  end

  defp calculate_min_score(results) do
    results
    |> Enum.map(&Map.get(&1, "score", 0.0))
    |> Enum.min(fn -> 0.0 end)
  end

  defp calculate_avg_score(results) do
    scores = Enum.map(results, &Map.get(&1, "score", 0.0))

    if length(scores) > 0 do
      Enum.sum(scores) / length(scores)
    else
      0.0
    end
  end

  defp categorize_scores(scores) do
    high_scores = Enum.count(scores, &(&1 >= 0.8))
    medium_scores = Enum.count(scores, &(&1 >= 0.5 and &1 < 0.8))
    low_scores = Enum.count(scores, &(&1 < 0.5))

    %{
      high: high_scores,
      medium: medium_scores,
      low: low_scores
    }
  end

  defp generate_performance_recommendations(avg_score, execution_time_ms, result_count) do
    recommendations = []

    recommendations =
      if avg_score < 0.5 do
        ["Consider query optimization for better relevance scores" | recommendations]
      else
        recommendations
      end

    recommendations =
      if execution_time_ms > 100 do
        ["Search execution time is high, consider index optimization" | recommendations]
      else
        recommendations
      end

    recommendations =
      if result_count > 1000 do
        ["Large result set returned, consider adding filters or pagination" | recommendations]
      else
        recommendations
      end

    recommendations =
      if result_count == 0 do
        [
          "No results found, consider expanding search criteria or fuzzy matching"
          | recommendations
        ]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["Search performance is optimal"]
    else
      recommendations
    end
  end
end
