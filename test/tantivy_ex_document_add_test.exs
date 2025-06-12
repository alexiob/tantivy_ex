defmodule TantivyExDocumentAddTest do
  use ExUnit.Case, async: true
  alias TantivyEx.{Schema, Index, IndexWriter, Document, Query, Searcher}

  test "document add and search" do
    # Create a schema
    schema =
      Schema.new()
      |> Schema.add_text_field("title", :text_stored)
      |> Schema.add_text_field("body", :text)

    # Create an index
    {:ok, index} = Index.create_in_ram(schema)
    {:ok, writer} = IndexWriter.new(index, 50_000_000)

    # Add a simple document
    doc = %{
      "title" => "Hello World",
      "body" => "This is a test document"
    }

    # Add the document and commit
    assert {:ok, _} = Document.add(writer, doc, schema)
    assert :ok = IndexWriter.commit(writer)

    # Search for the document
    {:ok, searcher} = Searcher.new(index)

    # Search by title as an exact term
    {:ok, query} = Query.term(schema, "title", "Hello World")
    {:ok, results} = Searcher.search(searcher, query, 10)

    # We should find one document
    assert length(results) == 1
    found_doc = hd(results)
    assert found_doc["title"] == "Hello World"
  end
end
