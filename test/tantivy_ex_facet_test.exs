defmodule TantivyExFacetTest do
  use ExUnit.Case, async: true
  alias TantivyEx.{Schema, Index, IndexWriter, Query, Searcher}

  setup do
    # Create a schema with a facet field
    schema =
      Schema.new()
      |> Schema.add_text_field("title", :text_stored)
      |> Schema.add_facet_field("tags")

    # Create an in-memory index
    {:ok, index} = Index.create_in_ram(schema)
    {:ok, writer} = IndexWriter.new(index, 50_000_000)

    %{schema: schema, index: index, writer: writer}
  end

  test "basic document indexing works", %{writer: writer, index: index} do
    # First verify basic indexing works
    doc = %{
      "title" => "Test Document"
    }

    :ok = IndexWriter.add_document(writer, doc)
    :ok = IndexWriter.commit(writer)

    # Search using all query
    {:ok, searcher} = Searcher.new(index)
    {:ok, query} = Query.all()
    {:ok, results} = Searcher.search(searcher, query, 10)

    assert length(results) == 1
    assert results |> List.first() |> Map.get("title") == "Test Document"
  end

  test "debug facet field storage", %{schema: schema, writer: writer, index: index} do
    # Add a document with both text and facet fields
    doc = %{
      "title" => "Test Document With Facet",
      "tags" => "/tag/elixir"
    }

    :ok = IndexWriter.add_document(writer, doc)
    :ok = IndexWriter.commit(writer)

    # First verify the document exists with a general query
    {:ok, searcher} = Searcher.new(index)
    {:ok, all_query} = Query.all()
    {:ok, all_results} = Searcher.search(searcher, all_query, 10)

    IO.puts("All documents: #{length(all_results)}")
    if length(all_results) > 0 do
      result = List.first(all_results)
      IO.puts("First document fields: #{inspect(Map.keys(result))}")
      IO.puts("Title: #{result["title"]}")
      IO.puts("Tags field present: #{Map.has_key?(result, "tags")}")
      if Map.has_key?(result, "tags") do
        IO.puts("Tags value: #{inspect(result["tags"])}")
      end
    end

    # Now try the facet query
    {:ok, facet_query} = Query.facet_term(schema, "tags", "/tag/elixir")
    {:ok, facet_results} = Searcher.search(searcher, facet_query, 10)
    IO.puts("Facet query results: #{length(facet_results)}")

    assert length(all_results) == 1
    # For now, just verify the document was indexed correctly
  end

  test "multiple documents with different tags", %{schema: schema, writer: writer, index: index} do
    # Add multiple documents with different tags (using proper facet path format)
    docs = [
      %{"title" => "Elixir Doc", "tags" => ["/tag/elixir", "/tag/functional"]},
      %{"title" => "Python Doc", "tags" => ["/tag/python", "/tag/scripting"]},
      %{"title" => "Mixed Doc", "tags" => ["/tag/elixir", "/tag/python", "/tag/comparison"]}
    ]

    Enum.each(docs, fn doc ->
      :ok = IndexWriter.add_document(writer, doc)
    end)
    :ok = IndexWriter.commit(writer)

    # Search for documents with "elixir" tag
    {:ok, searcher} = Searcher.new(index)
    {:ok, query} = Query.facet_term(schema, "tags", "/tag/elixir")
    {:ok, results} = Searcher.search(searcher, query, 10)

    assert length(results) == 2
    titles = Enum.map(results, & &1["title"])
    assert "Elixir Doc" in titles
    assert "Mixed Doc" in titles
  end
end
