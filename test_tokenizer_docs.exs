#!/usr/bin/env elixir

# Script to test tokenizer documentation examples
Mix.install([{:tantivy_ex, path: "."}])

alias TantivyEx.{Schema, Index, Tokenizer}

defmodule TokenizerDocTest do
  def test_basic_usage do
    IO.puts("Testing basic tokenizer usage from documentation...")

    # Test basic tokenizer registration
    result = Tokenizer.register_default_tokenizers()
    IO.puts("Default tokenizers: #{result}")

    # Test listing tokenizers
    tokenizers = Tokenizer.list_tokenizers()
    IO.puts("Available tokenizers: #{inspect(tokenizers)}")

    # Test basic tokenization
    tokens = Tokenizer.tokenize_text("default", "The quick brown foxes are running!")
    IO.puts("Tokenized 'The quick brown foxes are running!' with default: #{inspect(tokens)}")

    tokens = Tokenizer.tokenize_text("simple", "Hello, World!")
    IO.puts("Tokenized 'Hello, World!' with simple: #{inspect(tokens)}")

    tokens = Tokenizer.tokenize_text("whitespace", "JavaScript React.js Node.js")
    IO.puts("Tokenized 'JavaScript React.js Node.js' with whitespace: #{inspect(tokens)}")

    tokens = Tokenizer.tokenize_text("keyword", "In Progress - Pending Review")
    IO.puts("Tokenized 'In Progress - Pending Review' with keyword: #{inspect(tokens)}")

    :ok
  end

  def test_custom_tokenizers do
    IO.puts("\nTesting custom tokenizer registration...")

    # Test individual tokenizer registration
    {:ok, msg} = Tokenizer.register_simple_tokenizer("my_simple")
    IO.puts("Simple tokenizer: #{msg}")

    {:ok, msg} = Tokenizer.register_whitespace_tokenizer("my_whitespace")
    IO.puts("Whitespace tokenizer: #{msg}")

    {:ok, msg} = Tokenizer.register_regex_tokenizer("my_regex", "\\w+")
    IO.puts("Regex tokenizer: #{msg}")

    {:ok, msg} = Tokenizer.register_ngram_tokenizer("my_ngram", 2, 3, false)
    IO.puts("N-gram tokenizer: #{msg}")

    :ok
  end

  def test_text_analyzers do
    IO.puts("\nTesting text analyzer registration...")

    {:ok, msg} = Tokenizer.register_text_analyzer(
      "english_full",
      "simple",
      true,
      "english",
      "english",
      50
    )
    IO.puts("Text analyzer: #{msg}")

    # Test convenience functions
    {:ok, msg} = Tokenizer.register_language_analyzer("french")
    IO.puts("Language analyzer: #{msg}")

    {:ok, msg} = Tokenizer.register_stemming_tokenizer("german")
    IO.puts("Stemming tokenizer: #{msg}")

    :ok
  end

  def test_schema_with_tokenizers do
    IO.puts("\nTesting schema with custom tokenizers...")

    schema = Schema.new()

    # Add fields with different tokenizers
    schema = Schema.add_text_field_with_tokenizer(schema, "title", :text_stored, "default")
    schema = Schema.add_text_field_with_tokenizer(schema, "content", :text, "default")
    schema = Schema.add_text_field_with_tokenizer(schema, "sku", :text_stored, "simple")
    schema = Schema.add_text_field_with_tokenizer(schema, "tags", :text, "whitespace")
    schema = Schema.add_text_field_with_tokenizer(schema, "status", :indexed, "keyword")

    # Create index and test
    {:ok, _index} = Index.create_in_ram(schema)
    IO.puts("Schema with custom tokenizers created successfully")

    :ok
  end

  def test_tokenization_comparison do
    IO.puts("\nTesting tokenization comparison...")

    sample_text = "The Quick-Brown Fox's Email: fox@example.com"
    tokenizers = ["default", "simple", "whitespace", "keyword"]

    IO.puts("Sample text: #{sample_text}")

    Enum.each(tokenizers, fn tokenizer ->
      try do
        tokens = Tokenizer.tokenize_text(tokenizer, sample_text)
        IO.puts("#{String.pad_trailing(tokenizer, 10)}: #{inspect(tokens)}")
      rescue
        e -> IO.puts("#{String.pad_trailing(tokenizer, 10)}: ERROR - #{inspect(e)}")
      end
    end)

    :ok
  end

  def run_all_tests do
    IO.puts("=== Tokenizer Documentation Examples Test ===\n")

    test_basic_usage()
    test_custom_tokenizers()
    test_text_analyzers()
    test_schema_with_tokenizers()
    test_tokenization_comparison()

    IO.puts("\n=== All tests completed ===")
  end
end

TokenizerDocTest.run_all_tests()
