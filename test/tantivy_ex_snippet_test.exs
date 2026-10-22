defmodule TantivyEx.SnippetTest do
  use ExUnit.Case, async: true

  alias TantivyEx.{Schema, Index, IndexWriter, Searcher, Query}

  @body "Le café du matin. Rust est un langage de programmation, et Rust aime la sûreté."

  setup do
    schema =
      Schema.new()
      |> Schema.add_text_field("title", :text_stored)
      |> Schema.add_text_field("body", :text)

    {:ok, index} = Index.create_in_ram(schema)
    {:ok, writer} = IndexWriter.new(index, 50_000_000)
    IndexWriter.add_document(writer, %{"title" => "Notes", "body" => @body})
    IndexWriter.commit(writer)

    {:ok, searcher} = Searcher.new(index)
    {:ok, parser} = Query.parser(index, ["title", "body"])

    %{searcher: searcher, parser: parser}
  end

  defp highlighted_terms(%{fragment: fragment, highlighted: highlighted}) do
    for {start, stop} <- highlighted, do: binary_part(fragment, start, stop - start)
  end

  test "highlights the query terms with byte ranges", %{searcher: searcher, parser: parser} do
    {:ok, query} = Query.parse(parser, "rust")

    assert {:ok, snippet} = Searcher.snippet(searcher, query, "body", @body)

    # Matched with the field's tokenizer: case-insensitive, and the ranges are
    # in bytes, after the multi-byte "é" of "café".
    assert highlighted_terms(snippet) == ["Rust", "Rust"]
    assert snippet.fragment =~ "Rust est un langage"
  end

  test "works on text that is not stored in the index", %{searcher: searcher, parser: parser} do
    {:ok, query} = Query.parse(parser, "langage")

    assert {:ok, snippet} =
             Searcher.snippet(searcher, query, "body", "Un autre texte, sur un langage.")

    assert highlighted_terms(snippet) == ["langage"]
  end

  test "limits the fragment to :max_num_chars", %{searcher: searcher, parser: parser} do
    {:ok, query} = Query.parse(parser, "sûreté")

    assert {:ok, snippet} = Searcher.snippet(searcher, query, "body", @body, max_num_chars: 20)

    assert String.length(snippet.fragment) <= 20
    assert highlighted_terms(snippet) == ["sûreté"]
  end

  test "only highlights terms of the given field", %{searcher: searcher, parser: parser} do
    {:ok, query} = Query.parse(parser, "title:notes")

    assert {:ok, %{fragment: "", highlighted: []}} =
             Searcher.snippet(searcher, query, "body", "Des notes, encore des notes.")
  end

  test "returns an error for an unknown field", %{searcher: searcher, parser: parser} do
    {:ok, query} = Query.parse(parser, "rust")

    assert {:error, reason} = Searcher.snippet(searcher, query, "missing", @body)
    assert reason =~ "Field not found"
  end
end
