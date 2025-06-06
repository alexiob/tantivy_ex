# Tokenizers Guide

This guide covers text analysis and custom tokenizers in TantivyEx, helping you understand how text is processed for search.

## Table of Contents

- [Understanding Tokenizers](#understanding-tokenizers)
- [Built-in Tokenizers](#built-in-tokenizers)
- [Custom Tokenizer Usage](#custom-tokenizer-usage)
- [Tokenizer Selection Guide](#tokenizer-selection-guide)
- [Advanced Text Processing](#advanced-text-processing)
- [Real-world Examples](#real-world-examples)

## Understanding Tokenizers

Tokenizers are responsible for breaking down text into searchable terms (tokens). The choice of tokenizer significantly affects search behavior, performance, and user experience.

### What Tokenizers Do

1. **Split text** into individual terms
2. **Normalize text** (lowercase, remove punctuation)
3. **Apply filters** (stop words, stemming, synonyms)
4. **Generate tokens** that are stored in the search index

### Default Behavior

When you don't specify a tokenizer, TantivyEx uses Tantivy's default tokenizer:

```elixir
# Uses default tokenizer
{:ok, schema} = Schema.add_text_field(schema, "content", :TEXT)

# Equivalent to specifying "default" explicitly
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "content", :TEXT, "default")
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
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "article_content", :TEXT, "default")

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
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "product_code", :TEXT, "simple")

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
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "tags", :TEXT, "whitespace")

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
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "status", :TEXT, "keyword")

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
  schema, "title", :TEXT_STORED, "default"
)
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema, "content", :TEXT, "default"
)

# Product codes - use simple for exact matching
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema, "sku", :TEXT_STORED, "simple"
)

# Tags - use whitespace to preserve structure
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema, "tags", :TEXT, "whitespace"
)

# Status - use keyword for exact matching
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema, "status", :INDEXED, "keyword"
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
    {:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "default_field", :TEXT, "default")
    {:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "simple_field", :TEXT, "simple")
    {:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "whitespace_field", :TEXT, "whitespace")
    {:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "keyword_field", :TEXT, "keyword")
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
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "title", :TEXT_STORED, "default")
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "content", :TEXT, "default")
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "excerpt", :TEXT_STORED, "default")

# Tags - preserve individual tags
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "tags", :TEXT, "whitespace")

# Author name - could be searched as phrase
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "author", :TEXT_STORED, "simple")

# Category - exact matching
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "category", :INDEXED, "keyword")
```

#### E-commerce Products

```elixir
# Product name and description - natural search
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "name", :TEXT_STORED, "default")
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "description", :TEXT, "default")

# Brand - could be searched as phrase
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "brand", :TEXT_STORED, "simple")

# SKU/model - preserve structure
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "sku", :TEXT_STORED, "simple")
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "model", :TEXT_STORED, "simple")

# Product features/specs - preserve technical terms
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "features", :TEXT, "whitespace")
```

#### User Profiles

```elixir
# Name fields - phrase search
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "full_name", :TEXT_STORED, "simple")

# Bio/description - natural language
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "bio", :TEXT, "default")

# Username/email - exact structure
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "username", :TEXT_STORED, "simple")
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "email", :STORED, "simple")

# Skills/interests - individual terms
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "skills", :TEXT, "whitespace")
```

#### Log Analysis

```elixir
# Log message - natural language search
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "message", :TEXT, "default")

# Service/host names - preserve structure
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "service", :INDEXED, "simple")
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "hostname", :INDEXED, "simple")

# Log level - exact matching
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "level", :INDEXED, "keyword")

# Request URLs - preserve structure
{:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "request_url", :TEXT, "simple")
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
      schema, "content_en", :TEXT, "default"
    )

    # For languages without word separators (e.g., Chinese, Japanese)
    # Simple tokenizer might be more appropriate
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "content_cjk", :TEXT, "simple"
    )

    # For technical content with lots of punctuation
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "technical_content", :TEXT, "whitespace"
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

## Real-world Examples

### E-commerce Product Search

```elixir
defmodule MyApp.ProductSearchTokenizers do
  alias TantivyEx.{Schema, Index}

  def create_product_search_index(index_path) do
    {:ok, schema} = create_product_schema()
    {:ok, index} = Index.create(index_path, schema)

    # Index sample products
    sample_products()
    |> Enum.each(&Index.add_document(index, &1))

    Index.commit(index)
    {:ok, index}
  end

  defp create_product_schema do
    {:ok, schema} = Schema.new()

    # Product name - natural language search with stemming
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "name", :TEXT_STORED, "default"
    )

    # Description - comprehensive search
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "description", :TEXT, "default"
    )

    # Brand - exact brand name matching
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "brand", :TEXT_STORED, "simple"
    )

    # SKU and model - preserve alphanumeric codes
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "sku", :TEXT_STORED, "simple"
    )
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "model", :TEXT_STORED, "simple"
    )

    # Features/specifications - preserve technical terms
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "features", :TEXT, "whitespace"
    )

    # Category - exact hierarchy matching
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "category", :INDEXED, "keyword"
    )

    # Colors/sizes - individual values
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "colors", :TEXT, "whitespace"
    )

    {:ok, schema}
  end

  defp sample_products do
    [
      %{
        "name" => "Apple iPhone 15 Pro",
        "description" => "The latest iPhone with advanced camera system and A17 Pro chip",
        "brand" => "Apple",
        "sku" => "IPH15P-256-TIT",
        "model" => "A3108",
        "features" => "6.1-inch ProMotion display 48MP camera A17-Pro-chip Face-ID",
        "category" => "/electronics/phones/smartphones",
        "colors" => "Titanium Black White Blue"
      },
      %{
        "name" => "Samsung Galaxy S24 Ultra",
        "description" => "Premium Android phone with S Pen and AI features",
        "brand" => "Samsung",
        "sku" => "SGS24U-512-BLK",
        "model" => "SM-S928B",
        "features" => "6.8-inch Dynamic-AMOLED 200MP camera Snapdragon-8-Gen-3 S-Pen",
        "category" => "/electronics/phones/smartphones",
        "colors" => "Black Gray Violet Yellow"
      }
    ]
  end

  def demonstrate_search_behavior(index) do
    IO.puts("=== Product Search Tokenizer Demonstration ===\n")

    search_examples = [
      # Natural language search (works with default tokenizer)
      {"phones with good cameras", "Natural language search"},
      {"iPhone Pro", "Brand and model search"},

      # Technical searches (works with simple tokenizer)
      {"IPH15P-256-TIT", "Exact SKU search"},
      {"A3108", "Model number search"},
      {"Apple", "Brand search"},

      # Feature searches (works with whitespace tokenizer)
      {"48MP", "Megapixel search"},
      {"A17-Pro-chip", "Chip search"},
      {"6.1-inch", "Screen size search"},

      # Category searches (works with keyword tokenizer)
      {"/electronics/phones/smartphones", "Exact category"},

      # Color searches (works with whitespace tokenizer)
      {"Titanium", "Color search"},
      {"Black", "Color search"}
    ]

    Enum.each(search_examples, fn {query, description} ->
      IO.puts("#{description}: '#{query}'")
      test_search_across_fields(index, query)
      IO.puts("")
    end)
  end

  defp test_search_across_fields(index, query) do
    field_searches = [
      {"name:(#{query})", "name"},
      {"description:(#{query})", "description"},
      {"brand:(#{query})", "brand"},
      {"sku:(#{query})", "sku"},
      {"features:(#{query})", "features"},
      {"category:(#{query})", "category"},
      {"colors:(#{query})", "colors"}
    ]

    Enum.each(field_searches, fn {field_query, field_name} ->
      case Index.search(index, field_query, 5) do
        {:ok, results} when length(results) > 0 ->
          IO.puts("  ✓ Found in #{field_name} (#{length(results)} results)")
        {:ok, []} ->
          IO.puts("  ✗ Not found in #{field_name}")
        {:error, _} ->
          IO.puts("  ✗ Error searching #{field_name}")
      end
    end)
  end
end
```

### Blog Content Analysis

```elixir
defmodule MyApp.BlogTokenizers do
  alias TantivyEx.{Schema, Index}

  def create_blog_index(index_path) do
    {:ok, schema} = create_blog_schema()
    {:ok, index} = Index.create(index_path, schema)

    sample_posts()
    |> Enum.each(&Index.add_document(index, &1))

    Index.commit(index)
    {:ok, index}
  end

  defp create_blog_schema do
    {:ok, schema} = Schema.new()

    # Title - natural language with stemming
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "title", :TEXT_STORED, "default"
    )

    # Content - comprehensive text search
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "content", :TEXT, "default"
    )

    # Author name - phrase search (preserve full names)
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "author", :TEXT_STORED, "simple"
    )

    # Tags - individual tag search
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "tags", :TEXT, "whitespace"
    )

    # Category - exact category matching
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "category", :INDEXED, "keyword"
    )

    # Status - exact status matching
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "status", :INDEXED, "keyword"
    )

    {:ok, schema}
  end

  defp sample_posts do
    [
      %{
        "title" => "Getting Started with Elixir Programming",
        "content" => "Elixir is a functional programming language built on the Erlang virtual machine...",
        "author" => "Jane Smith",
        "tags" => "Elixir Programming Functional BEAM Erlang",
        "category" => "Programming",
        "status" => "published"
      },
      %{
        "title" => "Advanced Phoenix LiveView Patterns",
        "content" => "Phoenix LiveView enables rich interactive experiences without JavaScript...",
        "author" => "John Doe",
        "tags" => "Phoenix LiveView Elixir Web Real-time",
        "category" => "Web Development",
        "status" => "published"
      }
    ]
  end

  def analyze_content_tokenization(index) do
    IO.puts("=== Blog Content Tokenization Analysis ===\n")

    # Test different search patterns
    test_natural_language_search(index)
    test_exact_phrase_search(index)
    test_technical_term_search(index)
    test_author_search(index)
    test_tag_search(index)
    test_category_filter(index)
  end

  defp test_natural_language_search(index) do
    IO.puts("Natural Language Search (default tokenizer):")

    queries = [
      "programming languages",  # Should match "programming language"
      "functional",            # Should find functional programming
      "interactive experiences" # Should match content
    ]

    Enum.each(queries, fn query ->
      {:ok, results} = Index.search(index, "content:(#{query})", 5)
      IO.puts("  '#{query}': #{length(results)} results")
    end)

    IO.puts("")
  end

  defp test_exact_phrase_search(index) do
    IO.puts("Exact Phrase Search:")

    # Use quotes for exact phrases
    {:ok, results} = Index.search(index, "content:(\"Phoenix LiveView\")", 5)
    IO.puts("  'Phoenix LiveView': #{length(results)} results")

    {:ok, results} = Index.search(index, "content:(\"functional programming\")", 5)
    IO.puts("  'functional programming': #{length(results)} results")

    IO.puts("")
  end

  defp test_technical_term_search(index) do
    IO.puts("Technical Term Search (whitespace tokenizer in tags):")

    terms = ["Elixir", "Phoenix", "LiveView", "BEAM"]

    Enum.each(terms, fn term ->
      {:ok, results} = Index.search(index, "tags:(#{term})", 5)
      IO.puts("  '#{term}': #{length(results)} results")
    end)

    IO.puts("")
  end

  defp test_author_search(index) do
    IO.puts("Author Search (simple tokenizer):")

    authors = ["Jane Smith", "John", "Smith"]

    Enum.each(authors, fn author ->
      {:ok, results} = Index.search(index, "author:(#{author})", 5)
      IO.puts("  '#{author}': #{length(results)} results")
    end)

    IO.puts("")
  end

  defp test_tag_search(index) do
    IO.puts("Tag Search (whitespace tokenizer):")

    # Test case-sensitive tag search
    tags = ["Elixir", "elixir", "Phoenix", "Real-time"]

    Enum.each(tags, fn tag ->
      {:ok, results} = Index.search(index, "tags:(#{tag})", 5)
      IO.puts("  '#{tag}': #{length(results)} results")
    end)

    IO.puts("")
  end

  defp test_category_filter(index) do
    IO.puts("Category Filter (keyword tokenizer):")

    categories = ["Programming", "Web Development", "programming"]

    Enum.each(categories, fn category ->
      {:ok, results} = Index.search(index, "category:(\"#{category}\")", 5)
      IO.puts("  '#{category}': #{length(results)} results")
    end)

    IO.puts("")
  end
end
```

### Log Processing System

```elixir
defmodule MyApp.LogTokenizers do
  alias TantivyEx.{Schema, Index}

  def create_log_index(index_path) do
    {:ok, schema} = create_log_schema()
    {:ok, index} = Index.create(index_path, schema)

    sample_logs()
    |> Enum.each(&Index.add_document(index, &1))

    Index.commit(index)
    {:ok, index}
  end

  defp create_log_schema do
    {:ok, schema} = Schema.new()

    # Log message - natural language search for error analysis
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "message", :TEXT, "default"
    )

    # Service name - preserve service identifiers
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "service", :INDEXED, "simple"
    )

    # Log level - exact matching
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "level", :INDEXED, "keyword"
    )

    # Request path - preserve URL structure
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "request_path", :TEXT, "simple"
    )

    # User agent - technical string preservation
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "user_agent", :TEXT, "whitespace"
    )

    {:ok, schema}
  end

  defp sample_logs do
    [
      %{
        "message" => "Database connection timeout after 30 seconds",
        "service" => "user-service-v2",
        "level" => "ERROR",
        "request_path" => "/api/v1/users/profile",
        "user_agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
      },
      %{
        "message" => "User authentication successful for user ID 12345",
        "service" => "auth-gateway",
        "level" => "INFO",
        "request_path" => "/auth/login",
        "user_agent" => "MyApp/1.2.3 (iOS 17.0; iPhone15,2)"
      },
      %{
        "message" => "Rate limit exceeded for IP 192.168.1.100",
        "service" => "api-gateway",
        "level" => "WARN",
        "request_path" => "/api/v2/data/export",
        "user_agent" => "curl/7.68.0"
      }
    ]
  end

  def demonstrate_log_search_patterns(index) do
    IO.puts("=== Log Search Pattern Demonstration ===\n")

    # Error analysis using natural language search
    error_analysis(index)

    # Service filtering using simple tokenizer
    service_filtering(index)

    # Level filtering using keyword tokenizer
    level_filtering(index)

    # Path analysis using simple tokenizer
    path_analysis(index)

    # User agent analysis using whitespace tokenizer
    user_agent_analysis(index)
  end

  defp error_analysis(index) do
    IO.puts("Error Analysis (default tokenizer on message):")

    error_queries = [
      "timeout",           # Should find timeout errors
      "connection",        # Should find connection issues
      "authentication",    # Should find auth-related logs
      "rate limit"         # Should find rate limiting
    ]

    Enum.each(error_queries, fn query ->
      {:ok, results} = Index.search(index, "message:(#{query})", 10)
      IO.puts("  '#{query}': #{length(results)} results")
    end)

    IO.puts("")
  end

  defp service_filtering(index) do
    IO.puts("Service Filtering (simple tokenizer):")

    services = [
      "user-service-v2",   # Exact service name
      "auth-gateway",      # Another service
      "user-service",      # Partial match should work
      "gateway"            # Partial match
    ]

    Enum.each(services, fn service ->
      {:ok, results} = Index.search(index, "service:(#{service})", 10)
      IO.puts("  '#{service}': #{length(results)} results")
    end)

    IO.puts("")
  end

  defp level_filtering(index) do
    IO.puts("Level Filtering (keyword tokenizer):")

    levels = ["ERROR", "INFO", "WARN", "error", "DEBUG"]

    Enum.each(levels, fn level ->
      {:ok, results} = Index.search(index, "level:(\"#{level}\")", 10)
      IO.puts("  '#{level}': #{length(results)} results")
    end)

    IO.puts("")
  end

  defp path_analysis(index) do
    IO.puts("Path Analysis (simple tokenizer):")

    paths = [
      "/api/v1/users/profile",  # Exact path
      "/api/v1",                # Path prefix
      "users",                  # Path component
      "/auth/login"             # Another exact path
    ]

    Enum.each(paths, fn path ->
      {:ok, results} = Index.search(index, "request_path:(#{path})", 10)
      IO.puts("  '#{path}': #{length(results)} results")
    end)

    IO.puts("")
  end

  defp user_agent_analysis(index) do
    IO.puts("User Agent Analysis (whitespace tokenizer):")

    agents = [
      "Mozilla/5.0",      # Browser identifier
      "iPhone15,2",       # Device identifier
      "curl/7.68.0",      # Tool identifier
      "MyApp/1.2.3"       # App identifier
    ]

    Enum.each(agents, fn agent ->
      {:ok, results} = Index.search(index, "user_agent:(#{agent})", 10)
      IO.puts("  '#{agent}': #{length(results)} results")
    end)

    IO.puts("")
  end
end
```

## Performance Considerations

### Tokenizer Performance Impact

Different tokenizers have different performance characteristics:

```elixir
defmodule MyApp.TokenizerPerformance do
  def benchmark_tokenizers do
    sample_texts = generate_sample_texts(1000)

    tokenizers = ["default", "simple", "whitespace", "keyword"]

    Enum.each(tokenizers, fn tokenizer ->
      {time, _result} = :timer.tc(fn ->
        benchmark_tokenizer(tokenizer, sample_texts)
      end)

      IO.puts("#{tokenizer} tokenizer: #{time / 1000} ms")
    end)
  end

  defp benchmark_tokenizer(tokenizer, texts) do
    {:ok, schema} = Schema.new()
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "content", :TEXT, tokenizer
    )

    {:ok, index} = Index.create("/tmp/benchmark_#{tokenizer}", schema)

    # Index all texts
    Enum.each(texts, fn text ->
      Index.add_document(index, %{"content" => text})
    end)

    Index.commit(index)
  end

  defp generate_sample_texts(count) do
    Enum.map(1..count, fn i ->
      "Sample text number #{i} with various words and punctuation! Email: user#{i}@example.com"
    end)
  end
end
```

### Index Size Considerations

```elixir
defmodule MyApp.IndexSizeAnalysis do
  def compare_index_sizes do
    sample_documents = generate_sample_documents(1000)

    tokenizers = ["default", "simple", "whitespace", "keyword"]

    Enum.each(tokenizers, fn tokenizer ->
      index_path = "/tmp/size_test_#{tokenizer}"
      create_index_with_tokenizer(index_path, tokenizer, sample_documents)

      size = get_directory_size(index_path)
      IO.puts("#{tokenizer} tokenizer index size: #{size} MB")
    end)
  end

  defp create_index_with_tokenizer(path, tokenizer, documents) do
    {:ok, schema} = Schema.new()
    {:ok, schema} = Schema.add_text_field_with_tokenizer(
      schema, "content", :TEXT, tokenizer
    )

    {:ok, index} = Index.create(path, schema)

    Enum.each(documents, &Index.add_document(index, &1))
    Index.commit(index)
  end

  defp get_directory_size(path) do
    case File.ls(path) do
      {:ok, files} ->
        total_size =
          files
          |> Enum.map(&Path.join(path, &1))
          |> Enum.map(&File.stat!/1)
          |> Enum.map(& &1.size)
          |> Enum.sum()

        Float.round(total_size / (1024 * 1024), 2)
      {:error, _} -> 0
    end
  end

  defp generate_sample_documents(count) do
    Enum.map(1..count, fn i ->
      %{
        "content" => """
        Document #{i}: This is a sample document with various content.
        It contains email addresses like user#{i}@example.com,
        technical terms like API-v2.#{i}, and regular text.
        The document discusses programming, web development, and technology.
        """
      }
    end)
  end
end
```

## Best Practices Summary

1. **Choose the right tokenizer for your use case**:
   - `default`: Natural language content
   - `simple`: Technical identifiers, codes
   - `whitespace`: Tags, structured data
   - `keyword`: Exact matching, status values

2. **Consider search requirements**:
   - Fuzzy search needs `default` tokenizer
   - Exact matching needs `simple` or `keyword`
   - Case sensitivity needs `whitespace` or `keyword`

3. **Test with real data**: Always test tokenizer behavior with your actual content

4. **Document your choices**: Keep track of which fields use which tokenizers

5. **Monitor performance**: Different tokenizers have different index sizes and speeds

6. **Plan for internationalization**: Consider language-specific requirements

7. **Use field-specific tokenizers**: Don't use the same tokenizer for all fields

8. **Consider query patterns**: Choose tokenizers that support your most common searches

9. **Balance precision and recall**: `default` gives broad matches, `keyword` gives exact matches

10. **Test edge cases**: Special characters, mixed languages, technical terms
