defmodule TantivyEx do
  @moduledoc """
  TantivyEx is an Elixir NIF wrapper for the Tantivy Rust full-text search engine library.

  Tantivy is a fast full-text search engine library written in Rust, inspired by Apache Lucene.
  This wrapper provides Elixir bindings to create search indices, add documents, and perform searches.

  ## Basic Usage

      # Create a schema
      schema = TantivyEx.Schema.new()
      schema = TantivyEx.Schema.add_text_field(schema, "title", "TEXT_STORED")
      schema = TantivyEx.Schema.add_text_field(schema, "body", "TEXT")

      # Create an index
      {:ok, index} = TantivyEx.Index.create_in_ram(schema)

      # Get an index writer
      {:ok, writer} = TantivyEx.IndexWriter.new(index, 50_000_000)

      # Add documents
      doc = %{"title" => "Hello World", "body" => "This is a test document"}
      :ok = TantivyEx.IndexWriter.add_document(writer, doc)
      :ok = TantivyEx.IndexWriter.commit(writer)

      # Search
      {:ok, searcher} = TantivyEx.Searcher.new(index)
      {:ok, results} = TantivyEx.Searcher.search(searcher, "hello", 10)
  """

  @doc """
  Returns the version of TantivyEx.
  """
  def version, do: "0.1.0"
end
