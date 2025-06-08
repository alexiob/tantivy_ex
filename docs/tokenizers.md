# Tokenizers Guide

**Updated for TantivyEx v0.2.0** - This comprehensive guide covers the new advanced tokenization system, text analysis capabilities, and multi-language support in TantivyEx.

## Quick Start

```elixir
# Start with default tokenizers (recommended)
TantivyEx.Tokenizer.register_default_tokenizers()

# List available tokenizers
tokenizers = TantivyEx.Tokenizer.list_tokenizers()
# ["default", "simple", "keyword", "whitespace", "raw", "en_stem", "fr_stem", ...]

# Test tokenization
tokens = TantivyEx.Tokenizer.tokenize_text("default", "The quick brown foxes are running!")
# ["quick", "brown", "fox", "run"]  # Notice stemming: foxes -> fox, running -> run

# Create schema with tokenizers
schema = TantivyEx.Schema.new()
|> TantivyEx.Schema.add_text_field_with_tokenizer("content", :text, "default")
|> TantivyEx.Schema.add_text_field_with_tokenizer("tags", :text, "whitespace")
```

## Related Documentation

- **[Schema Design Guide](schema.md)** - Choose the right tokenizers for your field types
- **[Document Operations Guide](documents.md)** - Understand how tokenizers affect document indexing
- **[Search Guide](search.md)** - Use tokenizer knowledge to write better queries
- **[Search Results Guide](search_results.md)** - Leverage tokenization for highlighting and snippets

## Table of Contents

- [Quick Start](#quick-start)
- [TantivyEx.Tokenizer Module](#tantivyextokenizer-module)
- [Understanding Tokenizers](#understanding-tokenizers)
- [Built-in Tokenizers](#built-in-tokenizers)
- [Custom Tokenizer Registration](#custom-tokenizer-registration)
- [Advanced Text Analyzers](#advanced-text-analyzers)
- [Multi-Language Support](#multi-language-support)
- [Tokenizer Selection Guide](#tokenizer-selection-guide)
- [Advanced Text Processing](#advanced-text-processing)
- [Language-Specific Tokenization](#language-specific-tokenization)
- [Performance Considerations](#performance-considerations)
- [Real-world Examples](#real-world-examples)
- [Troubleshooting](#troubleshooting)

## TantivyEx.Tokenizer Module

**New in v0.2.0:** The `TantivyEx.Tokenizer` module provides comprehensive tokenization functionality with a clean, Elixir-friendly API.

### Core Functions

#### Tokenizer Registration

```elixir
# Register all default tokenizers at once
"Default tokenizers registered successfully" = TantivyEx.Tokenizer.register_default_tokenizers()
# Registers: "default", "simple", "keyword", "whitespace", "raw"
# Plus language variants: "en_stem", "fr_stem", "de_stem", etc.
# And analyzers: "en_text" (English with stop words + stemming)

# Register specific tokenizer types
{:ok, _msg} = TantivyEx.Tokenizer.register_simple_tokenizer("my_simple")
{:ok, _msg} = TantivyEx.Tokenizer.register_whitespace_tokenizer("my_whitespace")
{:ok, _msg} = TantivyEx.Tokenizer.register_regex_tokenizer("email", "\\b[\\w._%+-]+@[\\w.-]+\\.[A-Z|a-z]{2,}\\b")
{:ok, _msg} = TantivyEx.Tokenizer.register_ngram_tokenizer("fuzzy", 2, 4, false)
```

#### Advanced Text Analyzers

```elixir
# Full-featured text analyzer with all filters
{:ok, _msg} = TantivyEx.Tokenizer.register_text_analyzer(
  "english_complete",     # name
  "simple",               # base tokenizer ("simple" or "whitespace")
  true,                   # lowercase filter
  "english",              # stop words language (or nil)
  "english",              # stemming language (or nil)
  50                      # max token length (or nil)
)

# Language-specific convenience functions (Elixir wrapper functions)
{:ok, _msg} = TantivyEx.Tokenizer.register_language_analyzer("french")  # -> "french_text"
{:ok, _msg} = TantivyEx.Tokenizer.register_stemming_tokenizer("german") # -> "german_stem"
```

#### Tokenization Operations

```elixir
# Basic tokenization
tokens = TantivyEx.Tokenizer.tokenize_text("default", "Hello world!")
# ["hello", "world"]

# Detailed tokenization with positions
detailed = TantivyEx.Tokenizer.tokenize_text_detailed("simple", "Hello World")
# [{"hello", 0, 5}, {"world", 6, 11}]

# List all registered tokenizers
available = TantivyEx.Tokenizer.list_tokenizers()
# ["default", "simple", "keyword", "whitespace", ...]

# Process pre-tokenized text
result = TantivyEx.Tokenizer.process_pre_tokenized_text(["pre", "tokenized", "words"])
```

#### Performance Testing

```elixir
# Benchmark tokenizer performance
{final_tokens, avg_microseconds} = TantivyEx.Tokenizer.benchmark_tokenizer(
  "default",
  "Sample text to tokenize",
  1000  # iterations
)
```

## Understanding Tokenizers

Tokenizers are the foundation of text search - they determine how your documents are broken down into searchable terms. Understanding tokenization is crucial for achieving accurate and efficient search results.

### What Tokenizers Do

The tokenization process involves several critical steps:

1. **Text Segmentation**: Breaking text into individual units (words, phrases, or characters)
2. **Normalization**: Converting text to a standard form (lowercase, Unicode normalization)
3. **Filtering**: Removing or transforming tokens (stop words, punctuation, special characters)
4. **Stemming/Lemmatization**: Reducing words to their root forms
5. **Token Generation**: Creating the final searchable terms for the index

### The Tokenization Pipeline

```text
Raw Text → Segmentation → Normalization → Filtering → Stemming → Index Terms
```

**Example transformation:**

```text
"The QUICK brown foxes are running!"
→ ["The", "QUICK", "brown", "foxes", "are", "running", "!"]  # Segmentation
→ ["the", "quick", "brown", "foxes", "are", "running", "!"]  # Normalization
→ ["quick", "brown", "foxes", "running"]                     # Stop word removal
→ ["quick", "brown", "fox", "run"]                           # Stemming
```

### Default Behavior

When you don't specify a tokenizer, TantivyEx uses Tantivy's default tokenizer:

```elixir
# Uses default tokenizer
{:ok, schema} = Schema.add_text_field(schema, "content", :text)

# Equivalent to specifying "default" explicitly
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "content", :text, "default")
```

### Impact on Search Behavior

Different tokenizers produce different search behaviors:

```elixir
# With stemming tokenizer
# Query: "running" matches documents containing "run", "runs", "running", "ran"

# With simple tokenizer
# Query: "running" only matches documents containing exactly "running"

# With keyword tokenizer
# Query: "running" only matches if the entire field value is "running"
```

## Built-in Tokenizers

### Default Tokenizer

The default tokenizer provides comprehensive text processing suitable for most search scenarios.

**Features:**

- Splits on whitespace and punctuation
- Converts to lowercase
- Removes common stop words
- Applies stemming

**Best for:**

- General content search
- Blog posts and articles
- Product descriptions
- Most text fields

**Example:**

```elixir
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "article_content", :text, "default")

# Input: "The Quick Brown Foxes are Running!"
# Tokens: ["quick", "brown", "fox", "run"]  # Notice stemming: foxes -> fox, running -> run
```

### Simple Tokenizer

The simple tokenizer performs minimal processing, preserving the original text structure.

**Features:**

- Splits only on whitespace
- Converts to lowercase
- Preserves punctuation and special characters

**Best for:**

- Product codes and SKUs
- Exact phrase matching
- Technical identifiers
- Fields where punctuation matters

**Example:**

```elixir
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "product_code", :text, "simple")

# Input: "SKU-12345-A"
# Tokens: ["sku-12345-a"]  # Preserved hyphen, lowercased
```

### Whitespace Tokenizer

The whitespace tokenizer splits only on whitespace characters.

**Features:**

- Splits only on spaces, tabs, newlines
- Preserves case
- Preserves all punctuation

**Best for:**

- Tag fields
- Category lists
- Fields where case and punctuation are significant

**Example:**

```elixir
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "tags", :text, "whitespace")

# Input: "JavaScript React.js Node.js"
# Tokens: ["JavaScript", "React.js", "Node.js"]  # Case and dots preserved
```

### Keyword Tokenizer

The keyword tokenizer treats the entire input as a single token.

**Features:**

- No splitting - entire field becomes one token
- Preserves case and punctuation
- Exact matching only

**Best for:**

- Status fields
- Category hierarchies
- Exact match requirements
- Enumerated values

**Example:**

```elixir
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "status", :text, "keyword")

# Input: "In Progress - Pending Review"
# Tokens: ["In Progress - Pending Review"]  # Single token, exact match required
```

## Custom Tokenizer Usage

### Basic Custom Tokenizer Setup

```elixir
alias TantivyEx.Schema

# Create schema with different tokenizers for different fields
{:ok, schema} = Schema.new()

# Article content - use default for comprehensive search
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema, "title", :text_stored, "default"
)
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema, "content", :text, "default"
)

# Product codes - use simple for exact matching
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema, "sku", :text_stored, "simple"
)

# Tags - use whitespace to preserve structure
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema, "tags", :text, "whitespace"
)

# Status - use keyword for exact matching
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema, "status", :indexed, "keyword"
)
```

### Tokenizer Comparison Example

```elixir
defmodule MyApp.TokenizerDemo do
  alias TantivyEx.{Schema, Index}

  def demonstrate_tokenizers do
    # Create index with different tokenizer fields
    {:ok, schema} = create_demo_schema()
    {:ok, index} = Index.create("/tmp/tokenizer_demo", schema)

    # Add sample document
    sample_text = "The Quick-Brown Fox's Email: fox@example.com"

    document = %{
      "default_field" => sample_text,
      "simple_field" => sample_text,
      "whitespace_field" => sample_text,
      "keyword_field" => sample_text
    }

    {:ok, writer} = TantivyEx.IndexWriter.new(index)
    TantivyEx.IndexWriter.add_document(writer, document)
    TantivyEx.IndexWriter.commit(writer)

    # Test different search behaviors
    test_searches(index)
  end

  defp create_demo_schema do
    {:ok, schema} = Schema.new()
    {:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "default_field", :text, "default")
    {:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "simple_field", :text, "simple")
    {:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "whitespace_field", :text, "whitespace")
    {:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "keyword_field", :text, "keyword")
    {:ok, schema}
  end

  defp test_searches(index) do
    searches = [
      {"fox", "Search for 'fox'"},
      {"quick-brown", "Search for 'quick-brown'"},
      {"fox@example.com", "Search for email"},
      {"Fox's", "Search with apostrophe"},
      {"The Quick-Brown Fox's Email: fox@example.com", "Exact match"}
    ]

    Enum.each(searches, fn {query, description} ->
      IO.puts("\n#{description}: '#{query}'")
      test_field_searches(index, query)
    end)
  end

  defp test_field_searches(index, query) do
    fields = ["default_field", "simple_field", "whitespace_field", "keyword_field"]
    searcher = TantivyEx.Searcher.new(index)

    Enum.each(fields, fn field ->
      field_query = "#{field}:(#{query})"
      case TantivyEx.Searcher.search(searcher, field_query, 1) do
        {:ok, results} ->
          found = length(results) > 0
          IO.puts("  #{field}: #{if found, do: "✓ Found", else: "✗ Not found"}")
        {:error, _} ->
          IO.puts("  #{field}: ✗ Search error")
      end
    end)
  end
end

# Run the demo
MyApp.TokenizerDemo.demonstrate_tokenizers()
```

## Tokenizer Management

TantivyEx provides comprehensive tokenizer management capabilities through the native interface, allowing you to register, configure, and enumerate tokenizers dynamically.

### Registering Custom Tokenizers

#### Default Tokenizers

The most convenient way to set up commonly used tokenizers is with the default registration:

```elixir
# Register all default tokenizers at once
message = TantivyEx.Tokenizer.register_default_tokenizers()
IO.puts(message)  # "Default tokenizers registered successfully"

# This registers: "default", "simple", "keyword", "whitespace", "raw",
# plus language-specific variants like "en_stem", "fr_stem", etc.
```

#### Individual Tokenizer Registration

For more granular control, register tokenizers individually:

```elixir
# Simple tokenizer - splits on punctuation and whitespace
{:ok, msg} = TantivyEx.Tokenizer.register_simple_tokenizer("my_simple")

# Whitespace tokenizer - splits only on whitespace
{:ok, msg} = TantivyEx.Tokenizer.register_whitespace_tokenizer("my_whitespace")

# Regex tokenizer - custom splitting pattern
{:ok, msg} = TantivyEx.Tokenizer.register_regex_tokenizer("my_regex", "\\w+")

# N-gram tokenizer - fixed-size character sequences
{:ok, msg} = TantivyEx.Tokenizer.register_ngram_tokenizer("my_ngram", 2, 3, false)
```

#### Advanced Text Analyzers

For sophisticated text processing with filters and stemming:

```elixir
# English text analyzer with full processing
{:ok, msg} = TantivyEx.Tokenizer.register_text_analyzer(
  "english_full",     # name
  "simple",           # base tokenizer
  true,               # lowercase
  "english",          # stop words language
  "english",          # stemming language
  true                # remove long tokens
)

# Multi-language support
languages = ["english", "french", "german", "spanish"]
for language <- languages do
  TantivyEx.Tokenizer.register_text_analyzer(
    "#{language}_analyzer",
    "simple",
    true,
    language,
    language,
    true
  )
end
```

### Listing Available Tokenizers

**New in v0.2.0:** You can now enumerate all registered tokenizers to verify configuration or implement dynamic tokenizer selection:

```elixir
# List all currently registered tokenizers
tokenizers = TantivyEx.Tokenizer.list_tokenizers()
IO.inspect(tokenizers)
# ["default", "simple", "keyword", "whitespace", "en_stem", "fr_stem", ...]

# Check if a specific tokenizer is available
if "my_custom" in TantivyEx.Tokenizer.list_tokenizers() do
  IO.puts("Custom tokenizer is available")
else
  # Register it if missing
  TantivyEx.Tokenizer.register_simple_tokenizer("my_custom")
end
```

### Dynamic Tokenizer Configuration

Build tokenizer configurations based on runtime requirements:

```elixir
defmodule MyApp.TokenizerConfig do
  alias TantivyEx.Tokenizer

  def setup_for_language(language) do
    # Register default tokenizers first
    Tokenizer.register_default_tokenizers()

    # Check what's available
    available = Tokenizer.list_tokenizers()
    IO.puts("Available tokenizers: #{inspect(available)}")

    # Add language-specific configuration
    case language do
      "en" -> setup_english_tokenizers()
      "es" -> setup_spanish_tokenizers()
      "multi" -> setup_multilingual_tokenizers()
      _ -> :ok
    end

    # Verify final configuration
    final_tokenizers = TantivyEx.Tokenizer.list_tokenizers()
    IO.puts("Final tokenizer count: #{length(final_tokenizers)}")
  end

  defp setup_english_tokenizers do
    TantivyEx.Tokenizer.register_text_analyzer("en_blog", "simple", true, "english", "english", true)
    TantivyEx.Tokenizer.register_text_analyzer("en_legal", "simple", true, "english", nil, false)
    TantivyEx.Tokenizer.register_regex_tokenizer("en_email", "[\\w\\._%+-]+@[\\w\\.-]+\\.[A-Za-z]{2,}")
  end

  defp setup_spanish_tokenizers do
    TantivyEx.Tokenizer.register_text_analyzer("es_content", "simple", true, "spanish", "spanish", true)
    TantivyEx.Tokenizer.register_regex_tokenizer("es_phone", "\\+?[0-9]{2,3}[\\s-]?[0-9]{3}[\\s-]?[0-9]{3}[\\s-]?[0-9]{3}")
  end

  defp setup_multilingual_tokenizers do
    # Minimal processing for multi-language content
    TantivyEx.Tokenizer.register_simple_tokenizer("multi_simple")
    TantivyEx.Tokenizer.register_whitespace_tokenizer("multi_whitespace")
  end
end
```

### Testing Tokenizers

Verify tokenizer behavior before using in production schemas:

```elixir
defmodule MyApp.TokenizerTester do
  alias TantivyEx.Tokenizer

  def test_tokenizer_suite do
    # Register all tokenizers
    Tokenizer.register_default_tokenizers()

    test_text = "Hello World! This is a TEST email: user@example.com"

    # Test each available tokenizer
    Tokenizer.list_tokenizers()
    |> Enum.each(fn tokenizer_name ->
      IO.puts("\n--- Testing: #{tokenizer_name} ---")

      case Tokenizer.tokenize_text(tokenizer_name, test_text) do
        {:ok, tokens} ->
          IO.puts("Tokens: #{inspect(tokens)}")
          IO.puts("Count: #{length(tokens)}")

        {:error, reason} ->
          IO.puts("Error: #{reason}")
      end
    end)
  end

  def compare_tokenizers(text, tokenizer_names) do
    results =
      tokenizer_names
      |> Enum.map(fn name ->
        try do
          tokens = TantivyEx.Tokenizer.tokenize_text(name, text)
          {name, tokens}
        rescue
          _ -> {name, :error}
        end
      end)
      |> Enum.filter(fn {_, tokens} -> tokens != :error end)

    IO.puts("\nTokenization Comparison for: \"#{text}\"")
    IO.puts(String.duplicate("-", 60))

    Enum.each(results, fn {name, tokens} ->
      IO.puts("#{String.pad_trailing(name, 15)}: #{inspect(tokens)}")
    end)

    results
  end
end

# Usage
MyApp.TokenizerTester.test_tokenizer_suite()
MyApp.TokenizerTester.compare_tokenizers(
  "user@example.com",
  ["default", "simple", "whitespace", "keyword"]
)
```

### Error Handling

Handle tokenizer registration and usage errors gracefully:

```elixir
defmodule MyApp.SafeTokenizers do
  alias TantivyEx.Tokenizer

  def safe_register_analyzer(name, config) do
    case Tokenizer.register_text_analyzer(
      name,
      config[:base] || "simple",
      config[:lowercase] || true,
      config[:stop_words],
      config[:stemming],
      config[:remove_long]
    ) do
      {:ok, message} ->
        {:ok, message}

      {:error, reason} ->
        Logger.warning("Failed to register tokenizer #{name}: #{reason}")
        {:error, reason}
    end
  end

  def ensure_tokenizer_exists(name) do
    if name in TantivyEx.Tokenizer.list_tokenizers() do
      :ok
    else
      Logger.info("Tokenizer #{name} not found, registering default")
      TantivyEx.Tokenizer.register_simple_tokenizer(name)
    end
  end
end
```

## Tokenizer Selection Guide

### Decision Matrix

| Use Case | Tokenizer | Reason |
|----------|-----------|--------|
| Article content | `default` | Full-text search with stemming |
| Product names | `default` | Natural language search |
| Product codes/SKUs | `simple` | Preserve structure, case-insensitive |
| Email addresses | `simple` | Preserve @ and dots |
| Tags/keywords | `whitespace` | Preserve individual terms |
| Status values | `keyword` | Exact matching only |
| Category paths | `keyword` | Exact hierarchy matching |
| User input/queries | `default` | Natural language processing |
| URLs | `simple` | Preserve structure |
| Technical terms | `whitespace` | Preserve case and dots |

### Content Type Guidelines

#### Blog/CMS Content

```elixir
# Title and content - natural language search
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "title", :text_stored, "default")
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "content", :text, "default")
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "excerpt", :text_stored, "default")

# Tags - preserve individual tags
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "tags", :text, "whitespace")

# Author name - could be searched as phrase
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "author", :text_stored, "simple")

# Category - exact matching
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "category", :indexed, "keyword")
```

#### E-commerce Products

```elixir
# Product name and description - natural search
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "name", :text_stored, "default")
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "description", :text, "default")

# Brand - could be searched as phrase
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "brand", :text_stored, "simple")

# SKU/model - preserve structure
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "sku", :text_stored, "simple")
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "model", :text_stored, "simple")

# Product features/specs - preserve technical terms
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "features", :text, "whitespace")
```

#### User Profiles

```elixir
# Name fields - phrase search
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "full_name", :text_stored, "simple")

# Bio/description - natural language
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "bio", :text, "default")

# Username/email - exact structure
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "username", :text_stored, "simple")
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "email", :STORED, "simple")

# Skills/interests - individual terms
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "skills", :text, "whitespace")
```

#### Log Analysis

```elixir
# Log message - natural language search
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "message", :text, "default")

# Service/host names - preserve structure
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "service", :indexed, "simple")
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "hostname", :indexed, "simple")

# Log level - exact matching
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "level", :indexed, "keyword")

# Request URLs - preserve structure
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "request_url", :text, "simple")
```

### Multi-Language Support

**New in v0.2.0:** TantivyEx provides built-in support for 17+ languages with language-specific stemming and stop word filtering.

#### Supported Languages

| Language | Code | Stemming | Stop Words | Convenience Function |
|----------|------|----------|------------|---------------------|
| English | `"en"` / `"english"` | ✅ | ✅ | `register_language_analyzer("english")` |
| French | `"fr"` / `"french"` | ✅ | ✅ | `register_language_analyzer("french")` |
| German | `"de"` / `"german"` | ✅ | ✅ | `register_language_analyzer("german")` |
| Spanish | `"es"` / `"spanish"` | ✅ | ✅ | `register_language_analyzer("spanish")` |
| Italian | `"it"` / `"italian"` | ✅ | ✅ | `register_language_analyzer("italian")` |
| Portuguese | `"pt"` / `"portuguese"` | ✅ | ✅ | `register_language_analyzer("portuguese")` |
| Russian | `"ru"` / `"russian"` | ✅ | ✅ | `register_language_analyzer("russian")` |
| Arabic | `"ar"` / `"arabic"` | ✅ | ✅ | `register_language_analyzer("arabic")` |
| Danish | `"da"` / `"danish"` | ✅ | ✅ | `register_language_analyzer("danish")` |
| Dutch | `"nl"` / `"dutch"` | ✅ | ✅ | `register_language_analyzer("dutch")` |
| Finnish | `"fi"` / `"finnish"` | ✅ | ✅ | `register_language_analyzer("finnish")` |
| Greek | `"el"` / `"greek"` | ✅ | ✅ | `register_language_analyzer("greek")` |
| Hungarian | `"hu"` / `"hungarian"` | ✅ | ✅ | `register_language_analyzer("hungarian")` |
| Norwegian | `"no"` / `"norwegian"` | ✅ | ✅ | `register_language_analyzer("norwegian")` |
| Romanian | `"ro"` / `"romanian"` | ✅ | ✅ | `register_language_analyzer("romanian")` |
| Swedish | `"sv"` / `"swedish"` | ✅ | ✅ | `register_language_analyzer("swedish")` |
| Tamil | `"ta"` / `"tamil"` | ✅ | ✅ | `register_language_analyzer("tamil")` |
| Turkish | `"tr"` / `"turkish"` | ✅ | ✅ | `register_language_analyzer("turkish")` |

#### Language-Specific Usage

```elixir
# Complete language analyzer (lowercase + stop words + stemming)
TantivyEx.Tokenizer.register_language_analyzer("english")
# Creates "english_text" tokenizer

# Stemming only
TantivyEx.Tokenizer.register_stemming_tokenizer("french")
# Creates "french_stem" tokenizer

# Custom language configuration
TantivyEx.Tokenizer.register_text_analyzer(
  "german_custom",
  "simple",
  true,        # lowercase
  "german",    # stop words
  "german",    # stemming
  100          # max token length
)
```

### Advanced Text Analyzers

Text analyzers provide the most sophisticated text processing by chaining multiple filters:

```elixir
defmodule MyApp.LanguageAwareSchema do
  def create_multilingual_schema do
    {:ok, schema} = Schema.new()

    # English content - default tokenizer works well
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "content_en", :text, "default"
    )

    # For languages without word separators (e.g., Chinese, Japanese)
    # Simple tokenizer might be more appropriate
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "content_cjk", :text, "simple"
    )

    # For technical content with lots of punctuation
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "technical_content", :text, "whitespace"
    )

    {:ok, schema}
  end
end
```

### Handling Special Characters

Different tokenizers handle special characters differently:

```elixir
defmodule MyApp.SpecialCharacterDemo do
  def test_special_characters do
    test_cases = [
      "user@example.com",
      "C++ programming",
      "file.extension.tar.gz",
      "API-v2.1",
      "$100.50",
      "multi-word-identifier",
      "IPv4: 192.168.1.1"
    ]

    Enum.each(test_cases, &analyze_tokenization/1)
  end

  defp analyze_tokenization(text) do
    IO.puts("\nAnalyzing: '#{text}'")
    IO.puts("Default tokenizer: comprehensive processing")
    IO.puts("Simple tokenizer: preserves structure, lowercased")
    IO.puts("Whitespace tokenizer: preserves case and punctuation")
    IO.puts("Keyword tokenizer: exact match only")
  end
end
```

### Custom Search Strategies

Different tokenizers enable different search strategies:

```elixir
defmodule MyApp.SearchStrategies do
  alias TantivyEx.Index

  def demonstrate_search_strategies(index) do
    # Strategy 1: Fuzzy matching with default tokenizer
    fuzzy_search(index, "programming")

    # Strategy 2: Exact code matching with simple tokenizer
    exact_code_search(index, "API-v2.1")

    # Strategy 3: Tag searching with whitespace tokenizer
    tag_search(index, "JavaScript")

    # Strategy 4: Status filtering with keyword tokenizer
    status_filter(index, "In Progress")
  end

  defp fuzzy_search(index, term) do
    # Works well with default tokenizer due to stemming
    queries = [
      term,                    # Exact term
      "#{term}~",             # Fuzzy search
      "#{String.slice(term, 0, -2)}*"  # Wildcard search
    ]

    searcher = TantivyEx.Searcher.new(index)
    Enum.each(queries, fn query ->
      {:ok, results} = TantivyEx.Searcher.search(searcher, "content:(#{query})", 5)
      IO.puts("Query '#{query}': #{length(results)} results")
    end)
  end

  defp exact_code_search(index, code) do
    # Best with simple tokenizer for technical identifiers
    query = "sku:(#{code})"
    searcher = TantivyEx.Searcher.new(index)
    {:ok, results} = TantivyEx.Searcher.search(searcher, query, 10)
    IO.puts("Exact code search: #{length(results)} results")

  defp fuzzy_search_example(index, term) do
    # Works well with "default" tokenizer
    query = "content:(#{term}~)"
    searcher = TantivyEx.Searcher.new(index)
    {:ok, results} = TantivyEx.Searcher.search(searcher, query, 10)
    IO.puts("Fuzzy search: #{length(results)} results")
  end

  defp tag_search(index, tag) do
    # Whitespace tokenizer preserves individual tags
    query = "tags:(#{tag})"
    searcher = TantivyEx.Searcher.new(index)
    {:ok, results} = TantivyEx.Searcher.search(searcher, query, 10)
    IO.puts("Tag search: #{length(results)} results")
  end

  defp status_filter(index, status) do
    # Keyword tokenizer for exact status matching
    query = "status:(\"#{status}\")"
    searcher = TantivyEx.Searcher.new(index)
    {:ok, results} = TantivyEx.Searcher.search(searcher, query, 10)
    IO.puts("Status filter: #{length(results)} results")
  end
end
```

## Language-Specific Tokenization

### Multilingual Content

Handle multiple languages in your search index:

```elixir
defmodule MyApp.MultilingualTokenizer do
  def setup_multilingual_schema do
    {:ok, schema} = Schema.new()

    # English content with stemming
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "content_en", :text, "en_stem"
    )

    # Spanish content with stemming
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "content_es", :text, "default"
    )

    # Generic multilingual field
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "content_raw", :text, "simple"
    )

    schema
  end

  def index_multilingual_document(index, content, language) do
    {:ok, writer} = TantivyEx.IndexWriter.new(index)

    case language do
      "en" ->
        document = %{
          "content_en" => content,
          "content_raw" => content
        }
        TantivyEx.IndexWriter.add_document(writer, document)

      "es" ->
        document = %{
          "content_es" => content,
          "content_raw" => content
        }
        TantivyEx.IndexWriter.add_document(writer, document)

      _ ->
        document = %{"content_raw" => content}
        TantivyEx.IndexWriter.add_document(writer, document)
    end

    TantivyEx.IndexWriter.commit(writer)
  end

  def search_multilingual(index, query, language \\ nil) do
    searcher = TantivyEx.Searcher.new(index)
    case language do
      "en" -> TantivyEx.Searcher.search(searcher, "content_en:(#{query})", 10)
      "es" -> TantivyEx.Searcher.search(searcher, "content_es:(#{query})", 10)
      nil -> TantivyEx.Searcher.search(searcher, "content_raw:(#{query})", 10)
      _ -> TantivyEx.Searcher.search(searcher, "content_raw:(#{query})", 10)
    end
  end
end
```

### CJK (Chinese, Japanese, Korean) Support

Handle CJK languages that don't use spaces between words:

```elixir
defmodule MyApp.CJKTokenizer do
  def setup_cjk_schema do
    {:ok, schema} = Schema.new()

    # Use simple tokenizer for CJK content
    # In production, you might use specialized CJK tokenizers
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "content_cjk", :text, "simple"
    )

    # Keep original for fallback
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "content_original", :text, "raw"
    )

    schema
  end

  def preprocess_cjk_text(text) do
    text
    |> String.replace(~r/[[:punct:]]+/u, " ")  # Replace punctuation with spaces
    |> String.split()  # Split on whitespace
    |> Enum.join(" ")  # Rejoin with single spaces
  end

  def index_cjk_document(index, content) do
    processed_content = preprocess_cjk_text(content)

    document = %{
      "content_cjk" => processed_content,
      "content_original" => content
    }

    {:ok, writer} = TantivyEx.IndexWriter.new(index)
    TantivyEx.IndexWriter.add_document(writer, document)
    TantivyEx.IndexWriter.commit(writer)
  end
end
```

## Performance Considerations

### Tokenizer Performance Comparison

Different tokenizers have varying performance characteristics:

```elixir
defmodule MyApp.TokenizerBenchmark do
  def benchmark_tokenizers(sample_texts) do
    tokenizers = ["simple", "keyword", "default", "raw"]

    Enum.each(tokenizers, fn tokenizer ->
      {time, _result} = :timer.tc(fn ->
        benchmark_tokenizer(tokenizer, sample_texts)
      end)

      IO.puts("#{tokenizer}: #{time / 1000}ms")
    end)
  end

  defp benchmark_tokenizer(tokenizer, texts) do
    {:ok, schema} = Schema.new()
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "content", :text, tokenizer
    )

    {:ok, index} = Index.create("/tmp/benchmark_#{tokenizer}", schema)
    {:ok, writer} = TantivyEx.IndexWriter.new(index)

    Enum.each(texts, fn text ->
      TantivyEx.IndexWriter.add_document(writer, %{"content" => text})
    end)

    TantivyEx.IndexWriter.commit(writer)
  end
end
```

### Memory Usage Optimization

Monitor and optimize memory usage during tokenization:

```elixir
defmodule MyApp.TokenizerMemoryOptimizer do
  def optimize_for_large_documents(index, large_documents) do
    # Process documents in smaller chunks
    chunk_size = 100

    large_documents
    |> Stream.chunk_every(chunk_size)
    |> Enum.each(fn chunk ->
      process_chunk(index, chunk)

      # Force garbage collection between chunks
      :erlang.garbage_collect()

      # Optional: brief pause to prevent memory spikes
      Process.sleep(10)
    end)

    {:ok, writer} = TantivyEx.IndexWriter.new(index)
    TantivyEx.IndexWriter.commit(writer)
  end

  defp process_chunk(index, documents) do
    {:ok, writer} = TantivyEx.IndexWriter.new(index)
    Enum.each(documents, fn doc ->
      # Truncate very large fields to prevent memory issues
      truncated_doc = truncate_large_fields(doc)
      TantivyEx.IndexWriter.add_document(writer, truncated_doc)
    end)
    TantivyEx.IndexWriter.commit(writer)
  end

  defp truncate_large_fields(document) do
    max_field_size = 50_000  # 50KB per field

    Enum.reduce(document, %{}, fn {key, value}, acc ->
      truncated_value =
        if is_binary(value) && byte_size(value) > max_field_size do
          binary_part(value, 0, max_field_size)
        else
          value
        end

      Map.put(acc, key, truncated_value)
    end)
  end
end
```

### Index Size Optimization

Choose tokenizers based on index size requirements:

```elixir
defmodule MyApp.IndexSizeAnalyzer do
  def analyze_tokenizer_impact(documents) do
    tokenizers = ["simple", "keyword", "default"]

    Enum.map(tokenizers, fn tokenizer ->
      index_path = "/tmp/size_test_#{tokenizer}"
      create_test_index(index_path, tokenizer, documents)

      index_size = calculate_index_size(index_path)

      %{
        tokenizer: tokenizer,
        size_mb: index_size,
        size_per_doc: index_size / length(documents)
      }
    end)
  end

  defp create_test_index(path, tokenizer, documents) do
    {:ok, schema} = Schema.new()
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "content", :text, tokenizer
    )

    {:ok, index} = Index.create(path, schema)
    {:ok, writer} = TantivyEx.IndexWriter.new(index)

    Enum.each(documents, &TantivyEx.IndexWriter.add_document(writer, &1))
    TantivyEx.IndexWriter.commit(writer)
  end

  defp calculate_index_size(path) do
    case File.stat(path) do
      {:ok, stat} -> stat.size / (1024 * 1024)  # Convert to MB
      {:error, _} -> 0
    end
  end
end
```

## Real-world Examples

### E-commerce Product Search

Optimize tokenization for product catalogs:

```elixir
defmodule MyApp.EcommerceTokenizer do
  def setup_product_schema do
    {:ok, schema} = Schema.new()

    # Product titles - stemming for better matching
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "title", :text, "default"
    )

    # Brand names - exact matching important
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "brand", :text, "keyword"
    )

    # SKUs and model numbers - no transformation
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "sku", :text, "raw"
    )

    # Product descriptions - full text search
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "description", :text, "default"
    )

    # Category paths - hierarchical
    {:ok, schema} = Schema.add_facet_field(schema, "category")

    schema
  end

  def index_product(index, product) do
    document = %{
      "title" => product.title,
      "brand" => product.brand,
      "sku" => product.sku,
      "description" => product.description,
      "category" => format_category_path(product.category_path)
    }

    {:ok, writer} = TantivyEx.IndexWriter.new(index)
    TantivyEx.IndexWriter.add_document(writer, document)
    TantivyEx.IndexWriter.commit(writer)
  end

  def search_products(index, query, filters \\ %{}) do
    # Build multi-field query
    search_query = """
    (title:(#{query})^3 OR
     brand:(#{query})^2 OR
     description:(#{query}) OR
     sku:#{query}^4)
    """

    # Add filters
    filtered_query = apply_product_filters(search_query, filters)

    searcher = TantivyEx.Searcher.new(index)
    TantivyEx.Searcher.search(searcher, filtered_query, 50)
  end

  defp format_category_path(path_list) do
    "/" <> Enum.join(path_list, "/")
  end

  defp apply_product_filters(base_query, filters) do
    filter_parts = []

    filter_parts =
      if Map.has_key?(filters, :brand) do
        ["brand:\"#{filters.brand}\"" | filter_parts]
      else
        filter_parts
      end

    filter_parts =
      if Map.has_key?(filters, :category) do
        ["category:\"#{filters.category}/*\"" | filter_parts]
      else
        filter_parts
      end

    if length(filter_parts) > 0 do
      filter_string = Enum.join(filter_parts, " AND ")
      "(#{base_query}) AND (#{filter_string})"
    else
      base_query
    end
  end
end
```

### Document Management System

Handle various document types with appropriate tokenization:

```elixir
defmodule MyApp.DocumentTokenizer do
  def setup_document_schema do
    {:ok, schema} = Schema.new()

    # Document titles
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "title", :text, "default"
    )

    # Full document content
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "content", :text, "default"
    )

    # Author names - minimal processing
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "author", :text, "simple"
    )

    # File paths and names
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "filename", :text, "filename"
    )

    # Tags - exact matching
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "tags", :text, "keyword"
    )

    schema
  end

  def index_document(index, doc_metadata, content) do
    # Extract meaningful content based on file type
    processed_content = process_by_file_type(content, doc_metadata.file_type)

    document = %{
      "title" => doc_metadata.title || extract_title_from_filename(doc_metadata.filename),
      "content" => processed_content,
      "author" => doc_metadata.author,
      "filename" => doc_metadata.filename,
      "tags" => format_tags(doc_metadata.tags)
    }

    {:ok, writer} = TantivyEx.IndexWriter.new(index)
    TantivyEx.IndexWriter.add_document(writer, document)
    TantivyEx.IndexWriter.commit(writer)
  end

  defp process_by_file_type(content, file_type) do
    case file_type do
      "pdf" -> clean_pdf_content(content)
      "html" -> strip_html_tags(content)
      "markdown" -> process_markdown(content)
      "code" -> preserve_code_structure(content)
      _ -> content
    end
  end

  defp clean_pdf_content(content) do
    content
    |> String.replace(~r/\s+/, " ")  # Normalize whitespace
    |> String.replace(~r/[^\p{L}\p{N}\p{P}\p{Z}]/u, "")  # Remove non-printable chars
    |> String.trim()
  end

  defp strip_html_tags(html_content) do
    html_content
    |> String.replace(~r/<[^>]*>/, " ")  # Remove HTML tags
    |> String.replace(~r/&\w+;/, " ")    # Remove HTML entities
    |> String.replace(~r/\s+/, " ")      # Normalize whitespace
    |> String.trim()
  end

  defp process_markdown(markdown) do
    markdown
    |> String.replace(~r/#+\s*/, "")     # Remove markdown headers
    |> String.replace(~r/\*+([^*]+)\*+/, "\\1")  # Remove emphasis
    |> String.replace(~r/`([^`]+)`/, "\\1")      # Remove inline code
    |> String.replace(~r/\[([^\]]+)\]\([^)]+\)/, "\\1")  # Extract link text
  end

  defp preserve_code_structure(code) do
    # Preserve important code elements for search
    code
    |> String.replace(~r/\/\*.*?\*\//s, " ")  # Remove block comments
    |> String.replace(~r/\/\/.*$/m, "")       # Remove line comments
    |> String.replace(~r/\s+/, " ")           # Normalize whitespace
  end

  defp extract_title_from_filename(filename) do
    filename
    |> Path.basename()
    |> Path.rootname()
    |> String.replace(~r/[_-]/, " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_tags(tags) when is_list(tags) do
    Enum.join(tags, " ")
  end
  defp format_tags(tags) when is_binary(tags), do: tags
  defp format_tags(_), do: ""
end
```

## Troubleshooting

### Common Tokenization Issues

#### Issue: Search not finding expected results

**Problem**: Queries like "running" don't match documents containing "run"

**Solution**: Use a stemming tokenizer instead of simple:

```elixir
# Change from simple tokenizer
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema, "content", :text, "simple"
)

# To default tokenizer (includes stemming)
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema, "content", :text, "default"
)
```

#### Issue: Case-sensitive search behavior

**Problem**: Search for "iPhone" doesn't match "iphone"

**Solution**: Ensure your tokenizer includes lowercasing:

```elixir
# Raw tokenizer preserves case
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema, "product_name", :text, "raw"
)

# Simple tokenizer normalizes case
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema, "product_name", :text, "simple"
)
```

#### Issue: Special characters causing search problems

**Problem**: Searches for "<user@example.com>" or "API-v2.1" fail

**Solution**: Use keyword tokenizer for identifiers:

```elixir
# For email addresses, URLs, version numbers
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema, "email", :text, "keyword"
)

{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema, "version", :text, "keyword"
)
```

#### Issue: Poor performance with large documents

**Problem**: Indexing is slow with very large text fields

**Solution**: Consider field-specific optimization:

```elixir
defmodule MyApp.LargeDocumentOptimizer do
  def optimize_large_document(document) do
    # Truncate very large fields
    optimized = %{
      "title" => document["title"],
      "summary" => extract_summary(document["content"]),
      "content" => truncate_content(document["content"], 10_000),
      "keywords" => extract_keywords(document["content"])
    }

    optimized
  end

  defp extract_summary(content) do
    content
    |> String.split(~r/\.\s+/)
    |> Enum.take(3)
    |> Enum.join(". ")
  end

  defp truncate_content(content, max_chars) do
    if String.length(content) > max_chars do
      String.slice(content, 0, max_chars)
    else
      content
    end
  end

  defp extract_keywords(content) do
    # Simple keyword extraction
    content
    |> String.downcase()
    |> String.split(~r/\W+/)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(20)
    |> Enum.map(&elem(&1, 0))
    |> Enum.join(" ")
  end
end
```

### Debugging Tokenization

Test how your tokenizer processes text:

```elixir
defmodule MyApp.TokenizerDebugger do
  def debug_tokenization(text, tokenizer) do
    # Create a temporary index to test tokenization
    {:ok, schema} = Schema.new()
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "test_field", :text, tokenizer
    )

    {:ok, index} = Index.create("/tmp/debug_tokenizer", schema)

    # Add document
    document = %{"test_field" => text}
    {:ok, writer} = TantivyEx.IndexWriter.new(index)
    TantivyEx.IndexWriter.add_document(writer, document)
    TantivyEx.IndexWriter.commit(writer)

    # Test search behavior
    IO.puts("Original text: #{text}")
    IO.puts("Tokenizer: #{tokenizer}")

    # Test various search patterns
    test_searches = [
      String.downcase(text),
      String.upcase(text),
      text,
      "\"#{text}\"",  # Exact phrase
      String.split(text) |> hd(),  # First word
      String.split(text) |> List.last()  # Last word
    ]

    searcher = TantivyEx.Searcher.new(index)
    Enum.each(test_searches, fn query ->
      case TantivyEx.Searcher.search(searcher, query, 10) do
        {:ok, results} ->
          found = length(results) > 0
          IO.puts("Query '#{query}': #{if found, do: "FOUND", else: "NOT FOUND"}")

        {:error, reason} ->
          IO.puts("Query '#{query}': ERROR - #{inspect(reason)}")
      end
    end)

    # Cleanup
    File.rm_rf("/tmp/debug_tokenizer")
  end
end

# Usage
MyApp.TokenizerDebugger.debug_tokenization("Hello World", "simple")
MyApp.TokenizerDebugger.debug_tokenization("user@example.com", "keyword")
```

This comprehensive guide should help you understand and effectively use tokenizers in TantivyEx for optimal search performance and accuracy.
