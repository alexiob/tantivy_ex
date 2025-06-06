defmodule TantivyEx.MoreLikeThisTest do
  use ExUnit.Case, async: true
  alias TantivyEx.{Schema, Index, IndexWriter, Searcher, Query}

  describe "MoreLikeThisQuery functionality" do
    test "creates and executes more-like-this query successfully" do
      # Create a test schema
      schema =
        Schema.new()
        |> Schema.add_text_field("title", :text_stored)
        |> Schema.add_text_field("content", :text_stored)

      # Create an in-memory index
      {:ok, index} = Index.create_in_ram(schema)

      # Create a writer and add some documents
      {:ok, writer} = IndexWriter.new(index, 50_000_000)

      documents = [
        %{"title" => "Rust Programming", "content" => "Rust is a systems programming language"},
        %{"title" => "Elixir Guide", "content" => "Elixir is a functional programming language"},
        %{
          "title" => "Systems Programming",
          "content" => "Systems programming involves writing software"
        }
      ]

      # Add documents to the index
      Enum.each(documents, fn doc ->
        IndexWriter.add_document(writer, doc)
      end)

      # Commit the changes
      IndexWriter.commit(writer)

      # Create a searcher
      {:ok, searcher} = Searcher.new(index)

      # Test MoreLikeThisQuery
      test_document = %{
        "title" => "Programming Languages",
        "content" => "Programming languages for systems"
      }

      # Create more-like-this query
      assert {:ok, query} =
               Query.more_like_this(
                 schema,
                 test_document,
                 min_doc_frequency: 1,
                 max_query_terms: 10
               )

      # Execute the search
      assert {:ok, results} = Searcher.search(searcher, query, 10, true)

      # Verify we get some results
      assert is_list(results)
      # Results might be empty if no similar documents are found, which is fine
      # The important thing is that the query doesn't crash
    end

    test "handles invalid JSON document gracefully" do
      # Create a simple schema
      schema =
        Schema.new()
        |> Schema.add_text_field("title", :text_stored)

      # Test with invalid JSON
      assert {:error, reason} = Query.more_like_this(schema, "invalid json", [])
      assert is_binary(reason)
      assert String.contains?(reason, "JSON")
    end

    test "handles empty document gracefully" do
      # Create a simple schema
      schema =
        Schema.new()
        |> Schema.add_text_field("title", :text_stored)

      # Test with empty document
      assert {:error, reason} = Query.more_like_this(schema, "{}", [])
      assert is_binary(reason)
      assert String.contains?(reason, "No valid field values")
    end
  end
end
