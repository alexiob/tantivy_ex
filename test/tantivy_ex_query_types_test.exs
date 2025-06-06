defmodule TantivyEx.QueryTypesTest do
  @moduledoc """
  Comprehensive tests for all query types in TantivyEx.
  """
  use ExUnit.Case, async: true

  alias TantivyEx.{Schema, Index, IndexWriter, Searcher, Query}

  setup do
    # Create a comprehensive schema with multiple field types
    schema =
      Schema.new()
      |> Schema.add_text_field("title", :fast_stored)
      |> Schema.add_text_field("content", :fast_stored)
      |> Schema.add_u64_field("price", :fast_stored)
      |> Schema.add_i64_field("score", :fast_stored)
      |> Schema.add_f64_field("rating", :fast_stored)
      |> Schema.add_bool_field("active", :fast_stored)
      |> Schema.add_date_field("created_at", :fast_stored)

    # Create index and add test documents
    {:ok, index} = Index.create_in_ram(schema)
    {:ok, writer} = IndexWriter.new(index, 50_000_000)

    test_documents = [
      %{
        "title" => "Rust Programming Guide",
        "content" => "Learn Rust programming language with examples",
        "price" => 299,
        "score" => 95,
        "rating" => 4.8,
        "active" => true,
        "created_at" => 1_640_995_200
      },
      %{
        "title" => "Elixir Cookbook",
        "content" => "Functional programming recipes using Elixir",
        "price" => 199,
        "score" => -10,
        "rating" => 4.2,
        "active" => false,
        "created_at" => 1_640_908_800
      },
      %{
        "title" => "Systems Programming",
        "content" => "Low-level programming concepts and techniques",
        "price" => 399,
        "score" => 88,
        "rating" => 4.5,
        "active" => true,
        "created_at" => 1_641_081_600
      },
      %{
        "title" => "Web Development",
        "content" => "Building modern web applications",
        "price" => 249,
        "score" => 75,
        "rating" => 3.9,
        "active" => true,
        "created_at" => 1_641_168_000
      }
    ]

    Enum.each(test_documents, fn doc ->
      IndexWriter.add_document(writer, doc)
    end)

    IndexWriter.commit(writer)
    {:ok, searcher} = Searcher.new(index)

    %{schema: schema, index: index, searcher: searcher, writer: writer}
  end

  describe "term queries" do
    test "creates and executes term query successfully", %{schema: schema, searcher: searcher} do
      assert {:ok, query} = Query.term(schema, "title", "Rust")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "handles non-existent terms gracefully", %{schema: schema, searcher: searcher} do
      assert {:ok, query} = Query.term(schema, "title", "NonExistentTerm")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "handles invalid field names", %{schema: schema} do
      assert {:error, reason} = Query.term(schema, "invalid_field", "test")
      assert is_binary(reason)
    end
  end

  describe "phrase queries" do
    test "creates and executes phrase query successfully", %{schema: schema, searcher: searcher} do
      assert {:ok, query} = Query.phrase(schema, "content", ["programming", "language"])
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "handles single word phrases", %{schema: schema, searcher: searcher} do
      assert {:ok, query} = Query.phrase(schema, "title", ["Rust"])
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "handles empty phrase list", %{schema: schema} do
      assert {:error, reason} = Query.phrase(schema, "title", [])
      assert is_binary(reason)
    end
  end

  describe "range queries" do
    test "creates u64 range query", %{schema: schema, searcher: searcher} do
      assert {:ok, query} = Query.range_u64(schema, "price", 200, 300)
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "creates i64 range query", %{schema: schema, searcher: searcher} do
      assert {:ok, query} = Query.range_i64(schema, "score", 80, 100)
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "creates f64 range query", %{schema: schema, searcher: searcher} do
      assert {:ok, query} = Query.range_f64(schema, "rating", 4.0, 5.0)
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "handles invalid range (start > end)", %{schema: schema} do
      # This should either create a valid empty range or return error
      result = Query.range_u64(schema, "price", 300, 200)

      case result do
        {:ok, query} ->
          # Valid empty range query
          assert is_reference(query)

        {:error, reason} ->
          # Error is also acceptable
          assert is_binary(reason)
      end
    end
  end

  describe "boolean queries" do
    test "creates simple boolean query with must clauses", %{schema: schema, searcher: searcher} do
      {:ok, term1} = Query.term(schema, "title", "Programming")
      {:ok, term2} = Query.term(schema, "content", "language")

      assert {:ok, query} = Query.boolean([term1, term2], [], [])
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "creates boolean query with should clauses", %{schema: schema, searcher: searcher} do
      {:ok, term1} = Query.term(schema, "title", "Rust")
      {:ok, term2} = Query.term(schema, "title", "Elixir")

      assert {:ok, query} = Query.boolean([], [term1, term2], [])
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "creates boolean query with must_not clauses", %{schema: schema, searcher: searcher} do
      {:ok, term1} = Query.term(schema, "content", "programming")
      {:ok, term2} = Query.term(schema, "title", "Elixir")

      assert {:ok, query} = Query.boolean([term1], [], [term2])
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "creates complex boolean query with all clause types", %{
      schema: schema,
      searcher: searcher
    } do
      {:ok, must_term} = Query.term(schema, "content", "programming")
      {:ok, should_term1} = Query.term(schema, "title", "Rust")
      {:ok, should_term2} = Query.term(schema, "title", "Systems")
      {:ok, must_not_term} = Query.term(schema, "title", "Cookbook")

      assert {:ok, query} =
               Query.boolean([must_term], [should_term1, should_term2], [must_not_term])

      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "handles empty boolean query", %{schema: _schema, searcher: searcher} do
      assert {:ok, query} = Query.boolean([], [], [])
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end
  end

  describe "fuzzy queries" do
    test "creates fuzzy query with default parameters", %{schema: schema, searcher: searcher} do
      # Misspelled
      assert {:ok, query} = Query.fuzzy(schema, "title", "Programing")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "creates fuzzy query with custom distance", %{schema: schema, searcher: searcher} do
      assert {:ok, query} = Query.fuzzy(schema, "title", "Programing", 1)
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "creates fuzzy query with prefix disabled", %{schema: schema, searcher: searcher} do
      assert {:ok, query} = Query.fuzzy(schema, "title", "Programing", 2, false)
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end
  end

  describe "wildcard queries" do
    test "creates wildcard query with * pattern", %{schema: schema, searcher: searcher} do
      assert {:ok, query} = Query.wildcard(schema, "title", "Prog*")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "creates wildcard query with ? pattern", %{schema: schema, searcher: searcher} do
      assert {:ok, query} = Query.wildcard(schema, "title", "R?st")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end
  end

  describe "regex queries" do
    test "creates regex query successfully", %{schema: schema, searcher: searcher} do
      assert {:ok, query} = Query.regex(schema, "title", ".*Programming.*")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "handles invalid regex pattern", %{schema: schema} do
      # This should either compile the regex successfully or return an error
      result = Query.regex(schema, "title", "[invalid")

      case result do
        {:ok, query} ->
          # Some regex engines might handle this
          assert is_reference(query)

        {:error, reason} ->
          # Error is expected for invalid regex
          assert is_binary(reason)
      end
    end
  end

  describe "phrase prefix queries" do
    test "creates phrase prefix query with default expansions", %{
      schema: schema,
      searcher: searcher
    } do
      assert {:ok, query} = Query.phrase_prefix(schema, "content", ["programming", "lang"])
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "creates phrase prefix query with custom expansions", %{
      schema: schema,
      searcher: searcher
    } do
      assert {:ok, query} = Query.phrase_prefix(schema, "content", ["programming", "lang"], 10)
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end
  end

  describe "exists queries" do
    test "creates exists query successfully", %{schema: schema, searcher: searcher} do
      assert {:ok, query} = Query.exists(schema, "title")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "handles non-existent field names", %{schema: schema} do
      assert {:error, reason} = Query.exists(schema, "non_existent_field")
      assert is_binary(reason)
    end
  end

  describe "special queries" do
    test "creates all query", %{searcher: searcher} do
      assert {:ok, query} = Query.all()
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "creates empty query", %{searcher: searcher} do
      assert {:ok, query} = Query.empty()
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end
  end
end
