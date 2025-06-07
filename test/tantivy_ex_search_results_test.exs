defmodule TantivyEx.SearchResultsTest do
  use ExUnit.Case, async: true

  alias TantivyEx.{Schema, Index, IndexWriter, Searcher, Query, SearchResults}

  # Sample documents for testing
  @sample_documents [
    %{
      "title" => "Introduction to Elixir",
      "content" =>
        "Elixir is a dynamic, functional language designed for building maintainable and scalable applications.",
      "category" => "programming",
      "price" => 29.99,
      "published_at" => 1_640_995_200,
      "tags" => "elixir functional programming",
      "available" => true,
      "rating" => 4.5
    },
    %{
      "title" => "Advanced Elixir Patterns",
      "content" =>
        "Deep dive into advanced Elixir programming patterns and OTP design principles.",
      "category" => "programming",
      "price" => 49.99,
      "published_at" => 1_641_081_600,
      "tags" => "elixir otp advanced",
      "available" => true,
      "rating" => 4.8
    },
    %{
      "title" => "Web Development with Phoenix",
      "content" => "Building modern web applications using the Phoenix framework in Elixir.",
      "category" => "web development",
      "price" => 39.99,
      "published_at" => 1_641_168_000,
      "tags" => "phoenix web elixir",
      "available" => false,
      "rating" => 4.3
    },
    %{
      "title" => "Functional Programming Fundamentals",
      "content" => "Learn the core concepts of functional programming using various languages.",
      "category" => "programming",
      "price" => 34.99,
      "published_at" => 1_641_254_400,
      "tags" => "functional programming theory",
      "available" => true,
      "rating" => 4.1
    },
    %{
      "title" => "Rust System Programming",
      "content" => "System programming in Rust with focus on performance and memory safety.",
      "category" => "programming",
      "price" => 44.99,
      "published_at" => 1_641_340_800,
      "tags" => "rust systems programming",
      "available" => true,
      "rating" => 4.6
    }
  ]

  describe "basic functionality" do
    test "can call extract_query_terms with string" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", :text_stored)

      {:ok, terms} = SearchResults.extract_query_terms("hello world", schema)
      assert is_list(terms)
      assert "hello" in terms
      assert "world" in terms
    end
  end

  describe "process/3" do
    setup [:setup_index_with_data]

    test "processes basic search results", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.term(schema, "title", "elixir")
      {:ok, raw_results} = Searcher.search(searcher, query, 10)

      {:ok, processed} = SearchResults.process(raw_results, schema)

      assert is_list(processed)
      assert length(processed) > 0

      first_result = hd(processed)
      assert Map.has_key?(first_result, "score")
      assert Map.has_key?(first_result, "doc_id")
      assert Map.has_key?(first_result, "title")
    end

    test "applies schema validation and type conversion", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.term(schema, "category", "programming")
      {:ok, raw_results} = Searcher.search(searcher, query, 10)

      {:ok, processed} = SearchResults.process(raw_results, schema, schema_validation: true)

      first_result = hd(processed)
      assert is_float(Map.get(first_result, "price"))
      assert is_boolean(Map.get(first_result, "available"))
      assert is_float(Map.get(first_result, "rating"))
    end

    test "normalizes scores when option is enabled", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.term(schema, "title", "elixir")
      {:ok, raw_results} = Searcher.search(searcher, query, 10)

      {:ok, processed} = SearchResults.process(raw_results, schema, normalize_scores: true)

      first_result = hd(processed)
      assert Map.has_key?(first_result, "normalized_score")
      assert Map.get(first_result, "normalized_score") <= 1.0
      assert Map.get(first_result, "normalized_score") >= 0.0
    end

    test "handles empty results gracefully", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.term(schema, "title", "nonexistent")
      {:ok, raw_results} = Searcher.search(searcher, query, 10)

      {:ok, processed} = SearchResults.process(raw_results, schema)

      assert processed == []
    end

    test "returns error for invalid input" do
      invalid_schema = nil

      {:error, reason} = SearchResults.process([], invalid_schema)
      assert is_binary(reason)
      assert String.contains?(reason, "Failed to process results")
    end
  end

  describe "enhance/4" do
    setup [:setup_index_with_data]

    test "enhances results with string query highlighting", %{
      schema: schema,
      searcher: searcher,
      index: index
    } do
      query_string = "elixir programming"
      {:ok, parser} = Query.parser(index, ["title", "content"])
      {:ok, query} = Query.parse(parser, query_string)
      {:ok, raw_results} = Searcher.search(searcher, query, 10)

      options = [highlight: true, snippet_length: 100, include_metadata: true]
      {:ok, enhanced} = SearchResults.enhance(raw_results, schema, query_string, options)

      assert is_list(enhanced)
      assert length(enhanced) > 0

      first_result = hd(enhanced)
      assert Map.has_key?(first_result, "highlights")
      assert Map.has_key?(first_result, "snippet")
      assert Map.has_key?(first_result, "metadata")

      # Check highlights structure
      highlights = Map.get(first_result, "highlights")
      assert is_map(highlights)

      # Check metadata structure
      metadata = Map.get(first_result, "metadata")
      assert Map.has_key?(metadata, "position")
      assert Map.has_key?(metadata, "relevance_tier")
      assert Map.has_key?(metadata, "field_count")
    end

    test "enhances results with Query object highlighting", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.term(schema, "title", "elixir")
      {:ok, raw_results} = Searcher.search(searcher, query, 10)

      options = [highlight: true, max_highlights: 3]
      {:ok, enhanced} = SearchResults.enhance(raw_results, schema, query, options)

      assert is_list(enhanced)
      first_result = hd(enhanced)
      assert Map.has_key?(first_result, "highlights")
    end

    test "generates snippets with appropriate length", %{
      schema: schema,
      searcher: searcher,
      index: index
    } do
      query_string = "elixir"
      {:ok, parser} = Query.parser(index, ["title", "content"])
      {:ok, query} = Query.parse(parser, query_string)
      {:ok, raw_results} = Searcher.search(searcher, query, 10)

      options = [snippet_length: 50]
      {:ok, enhanced} = SearchResults.enhance(raw_results, schema, query_string, options)

      first_result = hd(enhanced)
      snippet = Map.get(first_result, "snippet", "")
      # Allow some buffer for ellipsis
      assert String.length(snippet) <= 60
    end

    test "customizes highlight tags", %{schema: schema, searcher: searcher, index: index} do
      query_string = "elixir"
      {:ok, parser} = Query.parser(index, ["title", "content"])
      {:ok, query} = Query.parse(parser, query_string)
      {:ok, raw_results} = Searcher.search(searcher, query, 10)

      options = [
        highlight: true,
        highlight_tags: {"<strong>", "</strong>"}
      ]

      {:ok, enhanced} = SearchResults.enhance(raw_results, schema, query_string, options)

      first_result = hd(enhanced)
      highlights = Map.get(first_result, "highlights", %{})

      # Check if custom tags are used
      highlight_text = highlights |> Map.values() |> List.flatten() |> Enum.join(" ")

      if String.length(highlight_text) > 0 do
        assert String.contains?(highlight_text, "<strong>")
        assert String.contains?(highlight_text, "</strong>")
      end
    end

    test "handles boolean queries", %{schema: schema, searcher: searcher} do
      {:ok, term1} = Query.term(schema, "title", "elixir")
      {:ok, term2} = Query.term(schema, "category", "programming")
      {:ok, boolean_query} = Query.boolean([term1], [term2], [])
      {:ok, raw_results} = Searcher.search(searcher, boolean_query, 10)

      options = [highlight: true, include_metadata: true]
      {:ok, enhanced} = SearchResults.enhance(raw_results, schema, boolean_query, options)

      assert is_list(enhanced)

      if length(enhanced) > 0 do
        first_result = hd(enhanced)
        assert Map.has_key?(first_result, "highlights")
        assert Map.has_key?(first_result, "metadata")
      end
    end
  end

  describe "paginate/2" do
    setup [:setup_index_with_data]

    test "paginates results correctly", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.all()
      {:ok, raw_results} = Searcher.search(searcher, query, 10)
      {:ok, processed} = SearchResults.process(raw_results, schema)

      {:ok, page1} = SearchResults.paginate(processed, page: 1, per_page: 2)

      assert Map.has_key?(page1, :items)
      assert Map.has_key?(page1, :metadata)

      items = Map.get(page1, :items)
      metadata = Map.get(page1, :metadata)

      assert length(items) <= 2
      assert Map.get(metadata, :current_page) == 1
      assert Map.get(metadata, :per_page) == 2
      assert Map.get(metadata, :has_prev) == false
      assert Map.get(metadata, :start_index) == 1
    end

    test "handles page beyond available results", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.all()
      {:ok, raw_results} = Searcher.search(searcher, query, 10)
      {:ok, processed} = SearchResults.process(raw_results, schema)

      {:ok, page} = SearchResults.paginate(processed, page: 100, per_page: 2)

      items = Map.get(page, :items)
      metadata = Map.get(page, :metadata)

      assert items == []
      assert Map.get(metadata, :current_page) == 100
      assert Map.get(metadata, :has_next) == false
    end

    test "includes total count when requested", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.all()
      {:ok, raw_results} = Searcher.search(searcher, query, 10)
      {:ok, processed} = SearchResults.process(raw_results, schema)

      {:ok, page} = SearchResults.paginate(processed, page: 1, per_page: 2, include_total: true)

      metadata = Map.get(page, :metadata)
      assert Map.has_key?(metadata, :total_count)
      assert Map.get(metadata, :total_count) == length(processed)
    end

    test "validates page parameters" do
      {:error, reason} = SearchResults.paginate([], page: 0, per_page: 10)
      assert String.contains?(reason, "positive integers")

      {:error, reason} = SearchResults.paginate([], page: 1, per_page: -1)
      assert String.contains?(reason, "positive integers")
    end
  end

  describe "aggregate/2" do
    setup [:setup_index_with_data]

    test "aggregates by single field", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.all()
      {:ok, raw_results} = Searcher.search(searcher, query, 10)
      {:ok, processed} = SearchResults.process(raw_results, schema)

      {:ok, facets} = SearchResults.aggregate(processed, ["category"])

      assert Map.has_key?(facets, "category")
      category_facets = Map.get(facets, "category")
      assert is_map(category_facets)
      assert Map.has_key?(category_facets, "programming")
    end

    test "aggregates by multiple fields", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.all()
      {:ok, raw_results} = Searcher.search(searcher, query, 10)
      {:ok, processed} = SearchResults.process(raw_results, schema)

      {:ok, facets} = SearchResults.aggregate(processed, ["category", "available"])

      assert Map.has_key?(facets, "category")
      assert Map.has_key?(facets, "available")

      available_facets = Map.get(facets, "available")
      assert is_map(available_facets)
    end

    test "handles numeric field aggregation with ranges", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.all()
      {:ok, raw_results} = Searcher.search(searcher, query, 10)
      {:ok, processed} = SearchResults.process(raw_results, schema)

      {:ok, facets} = SearchResults.aggregate(processed, ["price"])

      assert Map.has_key?(facets, "price")
      price_facets = Map.get(facets, "price")
      assert is_map(price_facets)

      # Should have price ranges
      price_ranges = Map.keys(price_facets)
      assert Enum.any?(price_ranges, &String.contains?(&1, "-"))
    end

    test "handles empty results" do
      {:ok, facets} = SearchResults.aggregate([], ["category"])
      assert Map.get(facets, "category") == %{}
    end

    test "handles missing fields gracefully", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.all()
      {:ok, raw_results} = Searcher.search(searcher, query, 10)
      {:ok, processed} = SearchResults.process(raw_results, schema)

      {:ok, facets} = SearchResults.aggregate(processed, ["nonexistent_field"])

      assert Map.get(facets, "nonexistent_field") == %{}
    end
  end

  describe "format_for_api/2" do
    setup [:setup_index_with_data]

    test "formats basic API response", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.term(schema, "title", "elixir")
      {:ok, raw_results} = Searcher.search(searcher, query, 10)
      {:ok, processed} = SearchResults.process(raw_results, schema)

      {:ok, api_response} = SearchResults.format_for_api(processed)

      assert Map.has_key?(api_response, :results)
      assert Map.has_key?(api_response, :metadata)

      metadata = Map.get(api_response, :metadata)
      assert Map.has_key?(metadata, :total_count)
      assert Map.has_key?(metadata, :max_score)
      assert Map.has_key?(metadata, :min_score)
      assert Map.has_key?(metadata, :avg_score)
    end

    test "includes optional metadata", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.term(schema, "title", "elixir")
      {:ok, raw_results} = Searcher.search(searcher, query, 10)
      {:ok, processed} = SearchResults.process(raw_results, schema)

      options = [
        query: "elixir programming",
        execution_time_ms: 25,
        search_type: "semantic"
      ]

      {:ok, api_response} = SearchResults.format_for_api(processed, options)

      metadata = Map.get(api_response, :metadata)
      assert Map.get(metadata, :query) == "elixir programming"
      assert Map.get(metadata, :execution_time_ms) == 25
      assert Map.get(metadata, :search_type) == "semantic"
    end

    test "handles empty results" do
      {:ok, api_response} = SearchResults.format_for_api([])

      metadata = Map.get(api_response, :metadata)
      assert Map.get(metadata, :total_count) == 0
      assert Map.get(metadata, :max_score) == 0.0
      assert Map.get(metadata, :min_score) == 0.0
      assert Map.get(metadata, :avg_score) == 0.0
    end
  end

  describe "analyze_performance/2" do
    setup [:setup_index_with_data]

    test "analyzes search performance metrics", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.term(schema, "title", "elixir")
      {:ok, raw_results} = Searcher.search(searcher, query, 10)
      {:ok, processed} = SearchResults.process(raw_results, schema)

      metrics = SearchResults.analyze_performance(processed, 15)

      assert Map.has_key?(metrics, :result_count)
      assert Map.has_key?(metrics, :execution_time_ms)
      assert Map.has_key?(metrics, :avg_score)
      assert Map.has_key?(metrics, :max_score)
      assert Map.has_key?(metrics, :min_score)
      assert Map.has_key?(metrics, :score_distribution)
      assert Map.has_key?(metrics, :recommendations)

      assert Map.get(metrics, :execution_time_ms) == 15
      assert Map.get(metrics, :result_count) == length(processed)

      score_distribution = Map.get(metrics, :score_distribution)
      assert Map.has_key?(score_distribution, :high)
      assert Map.has_key?(score_distribution, :medium)
      assert Map.has_key?(score_distribution, :low)

      recommendations = Map.get(metrics, :recommendations)
      assert is_list(recommendations)
      assert length(recommendations) > 0
    end

    test "provides recommendations based on performance", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.term(schema, "title", "nonexistent")
      {:ok, raw_results} = Searcher.search(searcher, query, 10)
      {:ok, processed} = SearchResults.process(raw_results, schema)

      # Test with no results - should recommend expanding search
      metrics = SearchResults.analyze_performance(processed, 15)
      recommendations = Map.get(metrics, :recommendations)

      recommendation_text = Enum.join(recommendations, " ")
      assert String.contains?(recommendation_text, "No results found")
    end

    test "handles high execution time recommendations" do
      metrics = SearchResults.analyze_performance([], 150)
      recommendations = Map.get(metrics, :recommendations)

      recommendation_text = Enum.join(recommendations, " ")
      assert String.contains?(recommendation_text, "execution time is high")
    end
  end

  describe "extract_query_terms/2" do
    setup [:setup_index_with_data]

    test "extracts terms from string queries", %{schema: schema} do
      {:ok, terms} = SearchResults.extract_query_terms("hello world programming", schema)

      assert is_list(terms)
      assert "hello" in terms
      assert "world" in terms
      assert "programming" in terms

      # Should filter out common stop words
      refute "the" in terms
      refute "and" in terms
    end

    test "extracts terms from Query objects", %{schema: schema} do
      {:ok, query} = Query.term(schema, "title", "elixir")
      {:ok, terms} = SearchResults.extract_query_terms(query, schema)

      assert is_list(terms)
      assert "elixir" in terms
    end

    test "extracts terms from boolean queries", %{schema: schema} do
      {:ok, term1} = Query.term(schema, "title", "elixir")
      {:ok, term2} = Query.term(schema, "content", "programming")
      {:ok, boolean_query} = Query.boolean([term1], [term2], [])

      {:ok, terms} = SearchResults.extract_query_terms(boolean_query, schema)

      assert is_list(terms)
      assert "elixir" in terms
      assert "programming" in terms
    end

    test "extracts terms from phrase queries", %{schema: schema} do
      {:ok, phrase_query} = Query.phrase(schema, "title", ["functional", "programming"])
      {:ok, terms} = SearchResults.extract_query_terms(phrase_query, schema)

      assert is_list(terms)
      assert "functional" in terms
      assert "programming" in terms
    end

    test "handles numeric query terms", %{schema: schema} do
      {:ok, range_query} = Query.range_f64(schema, "price", 20.0, 50.0)
      {:ok, terms} = SearchResults.extract_query_terms(range_query, schema)

      # Range queries should extract the boundary values
      assert is_list(terms)
    end

    test "removes duplicates and sorts terms", %{schema: schema} do
      {:ok, terms} = SearchResults.extract_query_terms("programming elixir programming", schema)

      # Should remove duplicates
      term_counts = Enum.frequencies(terms)
      assert Map.get(term_counts, "programming") == 1

      # Should be sorted
      assert terms == Enum.sort(terms)
    end

    test "handles empty and invalid queries", %{schema: schema} do
      {:ok, terms} = SearchResults.extract_query_terms("", schema)
      assert terms == []

      {:ok, terms} = SearchResults.extract_query_terms("   ", schema)
      assert terms == []
    end
  end

  describe "field type conversions" do
    setup [:setup_index_with_data]

    test "converts string fields correctly", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.all()
      {:ok, raw_results} = Searcher.search(searcher, query, 1)
      {:ok, processed} = SearchResults.process(raw_results, schema)

      result = hd(processed)
      assert is_binary(Map.get(result, "title"))
      assert is_binary(Map.get(result, "content"))
      assert is_binary(Map.get(result, "category"))
    end

    test "converts numeric fields correctly", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.all()
      {:ok, raw_results} = Searcher.search(searcher, query, 1)
      {:ok, processed} = SearchResults.process(raw_results, schema)

      result = hd(processed)
      assert is_float(Map.get(result, "price"))
      assert is_float(Map.get(result, "rating"))
    end

    test "converts boolean fields correctly", %{schema: schema, searcher: searcher} do
      {:ok, query} = Query.all()
      {:ok, raw_results} = Searcher.search(searcher, query, 1)
      {:ok, processed} = SearchResults.process(raw_results, schema)

      result = hd(processed)
      available = Map.get(result, "available")
      assert is_boolean(available)
    end
  end

  describe "error handling" do
    test "handles invalid schema gracefully" do
      {:error, reason} = SearchResults.process([], nil)
      assert is_binary(reason)
      assert String.contains?(reason, "Schema cannot be nil")
    end

    test "handles malformed results gracefully" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", :text_stored)

      malformed_results = [%{"invalid" => "data"}]
      {:ok, processed} = SearchResults.process(malformed_results, schema)
      assert is_list(processed)
    end

    test "handles aggregation errors gracefully" do
      {:error, reason} = SearchResults.aggregate("not_a_list", ["field"])
      assert is_binary(reason)
      assert String.contains?(reason, "Failed to aggregate results")
    end
  end

  # Helper function to set up index with sample data
  defp setup_index_with_data(_context) do
    # Create a comprehensive schema
    schema = Schema.new()
    schema = Schema.add_text_field(schema, "title", :text_stored)
    schema = Schema.add_text_field(schema, "content", :text_stored)
    schema = Schema.add_text_field(schema, "category", :text_stored)
    schema = Schema.add_f64_field(schema, "price", :fast_stored)
    schema = Schema.add_date_field(schema, "published_at", :fast_stored)
    schema = Schema.add_text_field(schema, "tags", :text_stored)
    schema = Schema.add_bool_field(schema, "available", :fast_stored)
    schema = Schema.add_f64_field(schema, "rating", :fast_stored)

    # Create index and add documents
    {:ok, index} = Index.create_in_ram(schema)
    {:ok, writer} = IndexWriter.new(index, 15_000_000)

    # Add sample documents
    Enum.each(@sample_documents, fn doc ->
      :ok = IndexWriter.add_document(writer, doc)
    end)

    :ok = IndexWriter.commit(writer)
    {:ok, searcher} = Searcher.new(index)

    %{schema: schema, index: index, searcher: searcher}
  end
end
