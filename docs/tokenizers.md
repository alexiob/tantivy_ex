# Tokenizers Guide

This comprehensive guide covers text analysis, tokenization strategies, custom tokenizers, and advanced text processing techniques in TantivyEx.

## Table of Contents

- [Understanding Tokenizers](#understanding-tokenizers)
- [Built-in Tokenizers](#built-in-tokenizers)
- [Custom Tokenizer Usage](#custom-tokenizer-usage)
- [Tokenizer Selection Guide](#tokenizer-selection-guide)
- [Advanced Text Processing](#advanced-text-processing)
- [Language-Specific Tokenization](#language-specific-tokenization)
- [Performance Considerations](#performance-considerations)
- [Real-world Examples](#real-world-examples)
- [Troubleshooting](#troubleshooting)

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

```
Raw Text → Segmentation → Normalization → Filtering → Stemming → Index Terms
```

**Example transformation:**

```
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

    Index.add_document(index, document)
    Index.commit(index)

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

    Enum.each(fields, fn field ->
      field_query = "#{field}:(#{query})"
      case Index.search(index, field_query, 1) do
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

## Advanced Text Processing

### Language-Specific Considerations

While TantivyEx uses Tantivy's built-in tokenizers, understanding language-specific requirements helps in tokenizer selection:

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

    Enum.each(queries, fn query ->
      {:ok, results} = Index.search(index, "content:(#{query})", 5)
      IO.puts("Query '#{query}': #{length(results)} results")
    end)
  end

  defp exact_code_search(index, code) do
    # Best with simple tokenizer for technical identifiers
    query = "sku:(#{code})"
    {:ok, results} = Index.search(index, query, 10)
    IO.puts("Exact code search: #{length(results)} results")
  end

  defp tag_search(index, tag) do
    # Whitespace tokenizer preserves individual tags
    query = "tags:(#{tag})"
    {:ok, results} = Index.search(index, query, 10)
    IO.puts("Tag search: #{length(results)} results")
  end

  defp status_filter(index, status) do
    # Keyword tokenizer for exact status matching
    query = "status:(\"#{status}\")"
    {:ok, results} = Index.search(index, query, 10)
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
    case language do
      "en" ->
        document = %{
          "content_en" => content,
          "content_raw" => content
        }
        Index.add_document(index, document)

      "es" ->
        document = %{
          "content_es" => content,
          "content_raw" => content
        }
        Index.add_document(index, document)

      _ ->
        document = %{"content_raw" => content}
        Index.add_document(index, document)
    end
  end

  def search_multilingual(index, query, language \\ nil) do
    case language do
      "en" -> Index.search(index, "content_en:(#{query})", 10)
      "es" -> Index.search(index, "content_es:(#{query})", 10)
      nil -> Index.search(index, "content_raw:(#{query})", 10)
      _ -> Index.search(index, "content_raw:(#{query})", 10)
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

    Index.add_document(index, document)
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

    Enum.each(texts, fn text ->
      Index.add_document(index, %{"content" => text})
    end)

    Index.commit(index)
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

    Index.commit(index)
  end

  defp process_chunk(index, documents) do
    Enum.each(documents, fn doc ->
      # Truncate very large fields to prevent memory issues
      truncated_doc = truncate_large_fields(doc)
      Index.add_document(index, truncated_doc)
    end)
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

    Enum.each(documents, &Index.add_document(index, &1))
    Index.commit(index)
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

    Index.add_document(index, document)
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

    Index.search(index, filtered_query, 50)
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

    Index.add_document(index, document)
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
    Index.add_document(index, document)
    Index.commit(index)

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

    Enum.each(test_searches, fn query ->
      case Index.search(index, query, 10) do
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
