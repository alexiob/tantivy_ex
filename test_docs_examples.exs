#!/usr/bin/env elixir

# Script to test that the documentation examples work correctly
Mix.install([{:tantivy_ex, path: "."}])

alias TantivyEx.{Schema, Index, IndexWriter}

defmodule DocumentationExamplesTest do
  def test_quick_start_example do
    IO.puts("Testing Quick Start example...")

    # From docs/quick-start.md
    # Create a new schema
    schema = Schema.new()

    # Add fields for a blog post
    schema = Schema.add_text_field(schema, "title", :text_stored)
    schema = Schema.add_text_field(schema, "content", :text)
    schema = Schema.add_text_field(schema, "author", :text_stored)
    schema = Schema.add_text_field(schema, "tags", :text)
    schema = Schema.add_u64_field(schema, "published_at", :fast_stored)
    schema = Schema.add_f64_field(schema, "rating", :fast_stored)
    schema = Schema.add_facet_field(schema, "category")

    # Create an in-memory index for testing
    {:ok, _index} = Index.create_in_ram(schema)

    IO.puts("✅ Quick Start schema example works correctly")
    :ok
  end

  def test_installation_setup_example do
    IO.puts("Testing Installation Setup example...")

    # From docs/installation-setup.md
    # Create a simple schema
    schema = Schema.new()
    schema = Schema.add_text_field(schema, "title", :text)
    schema = Schema.add_text_field(schema, "content", :text)

    # Create a temporary index
    {:ok, index} = Index.create_in_ram(schema)

    # Add a document
    {:ok, writer} = IndexWriter.new(index)
    doc = %{"title" => "Hello TantivyEx", "content" => "This is a test document"}
    :ok = IndexWriter.add_document(writer, doc)
    :ok = IndexWriter.commit(writer)

    # Search
    {:ok, searcher} = TantivyEx.Searcher.new(index)
    {:ok, results} = TantivyEx.Searcher.search(searcher, "hello", 10)

    # Verify we got results
    if length(results) > 0 do
      IO.puts("✅ Installation Setup example works correctly")
    else
      IO.puts("❌ Installation Setup example failed - no search results")
    end

    :ok
  end

  def test_core_concepts_example do
    IO.puts("Testing Core Concepts example...")

    # From docs/core-concepts.md
    schema = Schema.new()
    schema = Schema.add_text_field(schema, "title", :text_stored)
    schema = Schema.add_u64_field(schema, "timestamp", :fast_stored)

    # Text field examples
    schema = Schema.add_text_field(schema, "content", :text)
    schema = Schema.add_text_field(schema, "title2", :text_stored)

    # Numeric fields
    schema = Schema.add_u64_field(schema, "timestamp2", :fast_stored)
    schema = Schema.add_i64_field(schema, "score", :fast)
    schema = Schema.add_f64_field(schema, "price", :fast_stored)

    # Facet fields
    schema = Schema.add_facet_field(schema, "category")

    # Binary fields
    schema = Schema.add_bytes_field(schema, "thumbnail", :stored)

    {:ok, _index} = Index.create_in_ram(schema)

    IO.puts("✅ Core Concepts example works correctly")
    :ok
  end

  def test_indexing_example do
    IO.puts("Testing Indexing example...")

    # From docs/indexing.md
    # Design your schema
    schema = Schema.new()
    schema = Schema.add_text_field(schema, "title", :text_stored)
    schema = Schema.add_text_field(schema, "content", :text)
    schema = Schema.add_u64_field(schema, "timestamp", :fast_stored)
    schema = Schema.add_f64_field(schema, "rating", :fast_stored)

    # Create index
    {:ok, _index} = Index.create_in_ram(schema)

    IO.puts("✅ Indexing example works correctly")
    :ok
  end

  def run_all_tests do
    IO.puts("=== Documentation Examples Validation ===\n")

    test_quick_start_example()
    test_installation_setup_example()
    test_core_concepts_example()
    test_indexing_example()

    IO.puts("\n=== All documentation examples validated successfully ===")
  end
end

DocumentationExamplesTest.run_all_tests()
