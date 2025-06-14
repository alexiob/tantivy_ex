defmodule TantivyEx do
  @moduledoc """
  TantivyEx is an Elixir NIF wrapper for the Tantivy Rust full-text search engine library.

  Tantivy is a fast full-text search engine library written in Rust, inspired by Apache Lucene.
  This wrapper provides Elixir bindings to create search indices, add documents, perform searches,
  and run comprehensive aggregations.

  ## Basic Usage

      # Create a schema
      schema = TantivyEx.Schema.new()
      schema = TantivyEx.Schema.add_text_field(schema, "title", :text_stored)
      schema = TantivyEx.Schema.add_text_field(schema, "body", :text)

      # Create or open an index (recommended for production)
      {:ok, index} = TantivyEx.Index.open_or_create("/path/to/index", schema)

      # Alternative: Create in-memory index for testing
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

  ## Index Management

  TantivyEx provides several options for index creation and management:

      # Open existing or create new index (production recommended)
      {:ok, index} = TantivyEx.Index.open_or_create("/path/to/index", schema)

      # Create a new index (fails if already exists)
      {:ok, index} = TantivyEx.Index.create_in_dir("/path/to/index", schema)

      # Open an existing index (fails if doesn't exist)
      {:ok, index} = TantivyEx.Index.open("/path/to/index")

      # Create temporary in-memory index
      {:ok, index} = TantivyEx.Index.create_in_ram(schema)

  ## Advanced Aggregations

      # Terms aggregation
      aggregations = %{
        "categories" => TantivyEx.Aggregation.terms("category", size: 10)
      }
      {:ok, agg_results} = TantivyEx.Aggregation.run(searcher, query, aggregations)

      # Metric aggregations
      aggregations = %{
        "avg_price" => TantivyEx.Aggregation.metric(:avg, "price"),
        "price_stats" => TantivyEx.Aggregation.metric(:stats, "price")
      }

      # Complex nested aggregations
      price_histogram = TantivyEx.Aggregation.histogram("price", 10.0)
      |> TantivyEx.Aggregation.with_sub_aggregations(%{
        "avg_rating" => TantivyEx.Aggregation.metric(:avg, "rating")
      })

  ## Advanced Tokenization

      # Register custom tokenizers
      TantivyEx.Tokenizer.register_default_tokenizers()
      TantivyEx.Tokenizer.register_language_analyzer("en")

      # Use custom tokenizers in schema
      schema = TantivyEx.Schema.add_text_field_with_tokenizer(schema, "content", :text, "en_text")

      # Test tokenization
      tokens = TantivyEx.Tokenizer.tokenize_text("en_stem", "running quickly")
      # Returns: ["run", "quickli"]
  """

  @doc """
  Returns the version of TantivyEx.
  """
  def version, do: "0.3.3"
end
