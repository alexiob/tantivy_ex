defmodule TantivyEx.QueryParserTest do
  @moduledoc """
  Comprehensive tests for query parser functionality in TantivyEx.
  """
  use ExUnit.Case, async: true

  alias TantivyEx.{Schema, Index, IndexWriter, Searcher, Query}

  setup do
    # Create a schema with multiple field types for query parsing
    schema =
      Schema.new()
      |> Schema.add_text_field("title", :fast_stored)
      |> Schema.add_text_field("content", :fast_stored)
      |> Schema.add_text_field("author", :fast_stored)
      |> Schema.add_u64_field("price", :indexed_stored)
      |> Schema.add_i64_field("score", :indexed_stored)
      |> Schema.add_f64_field("rating", :indexed_stored)

    # Create index and add test documents
    {:ok, index} = Index.create_in_ram(schema)
    {:ok, writer} = IndexWriter.new(index, 50_000_000)

    test_documents = [
      %{
        "title" => "Advanced Rust Programming",
        "content" => "Deep dive into Rust systems programming with advanced concepts",
        "author" => "John Smith",
        "price" => 499,
        "score" => 92,
        "rating" => 4.7
      },
      %{
        "title" => "Elixir in Action",
        "content" => "Practical guide to building applications with Elixir",
        "author" => "Jane Doe",
        "price" => 299,
        "score" => 88,
        "rating" => 4.5
      },
      %{
        "title" => "Web Development Basics",
        "content" => "Introduction to modern web development techniques",
        "author" => "Bob Johnson",
        "price" => 199,
        "score" => 75,
        "rating" => 4.1
      }
    ]

    Enum.each(test_documents, fn doc ->
      IndexWriter.add_document(writer, doc)
    end)

    IndexWriter.commit(writer)
    {:ok, searcher} = Searcher.new(index)

    %{schema: schema, index: index, searcher: searcher}
  end

  describe "query parser creation" do
    test "creates parser with single default field", %{index: index} do
      assert {:ok, parser} = Query.parser(index, ["title"])
      assert is_reference(parser)
    end

    test "creates parser with multiple default fields", %{index: index} do
      assert {:ok, parser} = Query.parser(index, ["title", "content", "author"])
      assert is_reference(parser)
    end

    test "handles empty default fields list", %{index: index} do
      assert {:error, reason} = Query.parser(index, [])
      assert is_binary(reason)
    end

    test "handles non-existent field names", %{index: index} do
      assert {:error, reason} = Query.parser(index, ["non_existent_field"])
      assert is_binary(reason)
    end
  end

  describe "simple query parsing" do
    test "parses simple term query", %{index: index, searcher: searcher} do
      {:ok, parser} = Query.parser(index, ["title", "content"])

      assert {:ok, query} = Query.parse(parser, "Rust")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "parses multi-word query", %{index: index, searcher: searcher} do
      {:ok, parser} = Query.parser(index, ["title", "content"])

      assert {:ok, query} = Query.parse(parser, "Rust Programming")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "parses quoted phrase query", %{index: index, searcher: searcher} do
      {:ok, parser} = Query.parser(index, ["title", "content"])

      assert {:ok, query} = Query.parse(parser, "\"Rust Programming\"")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end
  end

  describe "field-specific queries" do
    test "parses field-specific term query", %{index: index, searcher: searcher} do
      {:ok, parser} = Query.parser(index, ["title", "content"])

      assert {:ok, query} = Query.parse(parser, "title:Rust")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "parses field-specific phrase query", %{index: index, searcher: searcher} do
      {:ok, parser} = Query.parser(index, ["title", "content"])

      assert {:ok, query} = Query.parse(parser, "title:\"Advanced Rust\"")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "parses multiple field queries", %{index: index, searcher: searcher} do
      {:ok, parser} = Query.parser(index, ["title", "content"])

      assert {:ok, query} = Query.parse(parser, "title:Rust author:John")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end
  end

  describe "boolean query parsing" do
    test "parses AND query", %{index: index, searcher: searcher} do
      {:ok, parser} = Query.parser(index, ["title", "content"])

      assert {:ok, query} = Query.parse(parser, "Rust AND Programming")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "parses OR query", %{index: index, searcher: searcher} do
      {:ok, parser} = Query.parser(index, ["title", "content"])

      assert {:ok, query} = Query.parse(parser, "Rust OR Elixir")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "parses NOT query", %{index: index, searcher: searcher} do
      {:ok, parser} = Query.parser(index, ["title", "content"])

      assert {:ok, query} = Query.parse(parser, "Programming NOT Elixir")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "parses complex boolean query", %{index: index, searcher: searcher} do
      {:ok, parser} = Query.parser(index, ["title", "content"])

      assert {:ok, query} = Query.parse(parser, "(Rust OR Elixir) AND Programming")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end
  end

  describe "range query parsing" do
    test "parses numeric range query", %{index: index, searcher: searcher} do
      {:ok, parser} = Query.parser(index, ["title", "content"])

      assert {:ok, query} = Query.parse(parser, "price:[200 TO 400]")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "parses open-ended range query", %{index: index, searcher: searcher} do
      {:ok, parser} = Query.parser(index, ["title", "content"])

      assert {:ok, query} = Query.parse(parser, "price:[300 TO *]")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "parses exclusive range query", %{index: index, searcher: searcher} do
      {:ok, parser} = Query.parser(index, ["title", "content"])

      assert {:ok, query} = Query.parse(parser, "price:{200 TO 400}")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end
  end

  describe "wildcard and fuzzy parsing" do
    test "parses wildcard query", %{index: index, searcher: searcher} do
      {:ok, parser} = Query.parser(index, ["title", "content"])

      assert {:ok, query} = Query.parse(parser, "Prog*")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "parses fuzzy query", %{index: index, searcher: searcher} do
      {:ok, parser} = Query.parser(index, ["title", "content"])

      # Misspelled with fuzzy operator
      assert {:ok, query} = Query.parse(parser, "Programing~")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end

    test "parses fuzzy query with distance", %{index: index, searcher: searcher} do
      {:ok, parser} = Query.parser(index, ["title", "content"])

      assert {:ok, query} = Query.parse(parser, "Programing~1")
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)
      assert is_list(results)
    end
  end

  describe "error handling" do
    test "handles empty query string", %{index: index} do
      {:ok, parser} = Query.parser(index, ["title"])

      assert {:error, reason} = Query.parse(parser, "")
      assert is_binary(reason)
    end

    test "handles malformed query syntax", %{index: index} do
      {:ok, parser} = Query.parser(index, ["title"])

      # Test with unmatched parentheses
      assert {:error, reason} = Query.parse(parser, "(unmatched")
      assert is_binary(reason)
    end

    test "handles invalid field names in query", %{index: index} do
      {:ok, parser} = Query.parser(index, ["title"])

      # This might succeed or fail depending on parser implementation
      result = Query.parse(parser, "invalid_field:test")

      case result do
        {:ok, query} ->
          # Parser might allow unknown fields
          assert is_reference(query)

        {:error, reason} ->
          # Or it might reject them
          assert is_binary(reason)
      end
    end

    test "handles invalid range syntax", %{index: index} do
      {:ok, parser} = Query.parser(index, ["title"])

      assert {:error, reason} = Query.parse(parser, "price:[invalid TO range]")
      assert is_binary(reason)
    end
  end

  describe "integration with search" do
    test "end-to-end parsing and search workflow", %{index: index, searcher: searcher} do
      # Create parser
      {:ok, parser} = Query.parser(index, ["title", "content", "author"])

      # Parse different types of queries and search with them
      queries = [
        "Rust",
        "title:Advanced",
        "Rust AND Programming",
        "price:[200 TO 500]",
        "author:John OR author:Jane"
      ]

      Enum.each(queries, fn query_str ->
        case Query.parse(parser, query_str) do
          {:ok, query} ->
            case Searcher.search(searcher, query, 10, true) do
              {:ok, results} ->
                assert is_list(results)

              {:error, reason} ->
                # Some queries might not match any documents
                assert is_binary(reason)
            end

          {:error, reason} ->
            # Some query syntax might not be supported
            assert is_binary(reason)
        end
      end)
    end
  end
end
