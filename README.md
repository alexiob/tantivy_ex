# TantivyEx

[![Elixir CI](https://github.com/alexiob/tantivy_ex/actions/workflows/ci.yml/badge.svg)](https://github.com/alexiob/tantivy_ex/actions)
[![Hex Version](https://img.shields.io/hexpm/v/tantivy_ex.svg)](https://hex.pm/packages/tantivy_ex)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/tantivy_ex/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

![TantivyEx Logo](assets/logo.png)

**A comprehensive Elixir wrapper for the Tantivy full-text search engine.**

TantivyEx provides a complete, type-safe interface to Tantivy - Rust's fastest full-text search library. Build powerful search applications with support for all Tantivy field types, custom tokenizers, schema introspection, and advanced indexing features.

## Features

- **High Performance**: Built on Tantivy, one of the fastest search engines available
- **Complete Field Type Support**: Text, numeric, boolean, date, facet, bytes, JSON, and IP address fields
- **Advanced Text Processing**: Comprehensive tokenizer system with 17+ language support, custom regex patterns, n-grams, and configurable text analyzers
- **Intelligent Text Analysis**: Stemming, stop word filtering, case normalization, and language-specific processing
- **Dynamic Tokenizer Management**: Runtime tokenizer registration, enumeration, and configuration
- **Schema Management**: Dynamic schema building with validation and introspection
- **Flexible Storage**: In-memory or persistent disk-based indexes
- **Type Safety**: Full Elixir typespecs and compile-time safety
- **Advanced Aggregations**: Elasticsearch-compatible bucket aggregations (terms, histogram, date_histogram, range) and metric aggregations (avg, min, max, sum, stats, percentiles) with nested sub-aggregations
- **Distributed Search**: Multi-node search coordination with load balancing, failover, and configurable result merging
- **Search Features**: Full-text search, faceted search, range queries, and comprehensive analytics

## Quick Start

```elixir
# Register tokenizers (recommended for production)
TantivyEx.Tokenizer.register_default_tokenizers()

# Create a schema with custom tokenizers
schema = TantivyEx.Schema.new()
|> TantivyEx.Schema.add_text_field_with_tokenizer("title", :text_stored, "default")
|> TantivyEx.Schema.add_text_field_with_tokenizer("body", :text, "default")
|> TantivyEx.Schema.add_u64_field("id", :indexed_stored)
|> TantivyEx.Schema.add_date_field("published_at", :fast)

# Create an index
# Option 1: Open existing or create new (recommended for production)
{:ok, index} = TantivyEx.Index.open_or_create("/path/to/index", schema)

# Option 2: Create in-memory index for testing
{:ok, index} = TantivyEx.Index.create_in_ram(schema)

# Option 3: Create new persistent index (fails if exists)
{:ok, index} = TantivyEx.Index.create_in_dir("/path/to/index", schema)

# Option 4: Open existing index (fails if doesn't exist)
{:ok, index} = TantivyEx.Index.open("/path/to/index")

# Get a writer
{:ok, writer} = TantivyEx.IndexWriter.new(index, 50_000_000)

# Add documents
doc = %{
  "title" => "Getting Started with TantivyEx",
  "body" => "This is a comprehensive guide to using TantivyEx...",
  "id" => 1,
  "published_at" => "2024-01-15T10:30:00Z"
}

:ok = TantivyEx.IndexWriter.add_document(writer, doc)
:ok = TantivyEx.IndexWriter.commit(writer)

# Search
{:ok, searcher} = TantivyEx.Searcher.new(index)
{:ok, results} = TantivyEx.Searcher.search(searcher, "comprehensive guide", 10)

# Advanced Aggregations (New in v0.2.0)
{:ok, query} = TantivyEx.Query.all()

# Terms aggregation for category analysis
aggregations = %{
  "categories" => %{
    "terms" => %{
      "field" => "category",
      "size" => 10
    }
  }
}

{:ok, agg_results} = TantivyEx.Aggregation.run(searcher, query, aggregations)

# Histogram aggregation for numerical analysis
price_histogram = %{
  "price_ranges" => %{
    "histogram" => %{
      "field" => "price",
      "interval" => 50.0
    }
  }
}

{:ok, histogram_results} = TantivyEx.Aggregation.run(searcher, query, price_histogram)

# Combined search with aggregations
{:ok, search_results, agg_results} = TantivyEx.Aggregation.search_with_aggregations(
  searcher,
  query,
  aggregations,
  20  # search limit
)

# Distributed Search (New in v0.3.0)
{:ok, _supervisor_pid} = TantivyEx.Distributed.OTP.start_link()

# Add multiple search nodes for horizontal scaling
:ok = TantivyEx.Distributed.OTP.add_node("node1", "http://localhost:9200", 1.0)
:ok = TantivyEx.Distributed.OTP.add_node("node2", "http://localhost:9201", 1.5)

# Configure distributed behavior
:ok = TantivyEx.Distributed.OTP.configure(%{
  timeout_ms: 5000,
  max_retries: 3,
  merge_strategy: :score_desc
})

# Perform distributed search
{:ok, results} = TantivyEx.Distributed.OTP.search("search query", 10, 0)

IO.puts("Found #{length(results)} hits across distributed nodes")
```

## Installation

Add `tantivy_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tantivy_ex, "~> 0.4.1"}
  ]
end
```

TantivyEx requires:

- **Elixir**: 1.18 or later
- **Rust**: 1.70 or later (for compilation)
- **System**: Compatible with Linux, macOS, and Windows

## Documentation

### Complete Guides

**[Browse All Guides →](docs/guides.md)**

#### Getting Started

- **[Installation & Setup](docs/installation-setup.md)**: Complete installation guide with configuration options
- **[Quick Start Tutorial](docs/quick-start.md)**: Hands-on tutorial for your first search application
- **[Core Concepts](docs/core-concepts.md)**: Essential concepts with comprehensive glossary

#### Development & Production

- **[Performance Tuning](docs/performance-tuning.md)**: Optimization strategies for indexing and search
- **[Production Deployment](docs/production-deployment.md)**: Scalability, monitoring, and operational best practices
- **[Integration Patterns](docs/integration-patterns.md)**: Phoenix/LiveView integration and advanced architectures

### API Documentation

#### Core Components

- **[Schema Management](docs/schema.md)**: Field types, options, and schema design patterns
- **[Document Operations](docs/documents.md)**: Adding, updating, and managing documents
- **[Indexing](docs/indexing.md)**: Index creation, writing, and maintenance
- **[Search Operations](docs/search.md)**: Query syntax, ranking, and search best practices
- **[Search Results](docs/search_results.md)**: Result handling and formatting
- **[Aggregations](docs/aggregations.md)**: Data analysis, bucket and metric aggregations, and analytics
- **[Distributed Search](docs/otp-distributed-implementation.md)**: Multi-node coordination, load balancing, and horizontal scaling
- **[Tokenizers](docs/tokenizers.md)**: Text analysis, custom tokenizers, and language support

#### API Reference

- **[TantivyEx](https://hexdocs.pm/tantivy_ex/TantivyEx.html)**: Main module with index operations
- **[TantivyEx.Schema](https://hexdocs.pm/tantivy_ex/TantivyEx.Schema.html)**: Schema definition and management
- **[TantivyEx.Aggregation](https://hexdocs.pm/tantivy_ex/TantivyEx.Aggregation.html)**: Data analysis and aggregation operations
- **[TantivyEx.Native](https://hexdocs.pm/tantivy_ex/TantivyEx.Native.html)**: Low-level NIF functions

## Field Types

TantivyEx supports all Tantivy field types with comprehensive options:

| Field Type | Elixir Function | Use Cases | Options |
|------------|----------------|-----------|---------|
| **Text** | `add_text_field/3` | Full-text search, titles, content | `:text`, `:text_stored`, `:stored`, `:fast`, `:fast_stored` |
| **U64** | `add_u64_field/3` | IDs, counts, timestamps | `:indexed`, `:indexed_stored`, `:fast`, `:stored`, `:fast_stored` |
| **I64** | `add_i64_field/3` | Signed integers, deltas | `:indexed`, `:indexed_stored`, `:fast`, `:stored`, `:fast_stored` |
| **F64** | `add_f64_field/3` | Prices, scores, coordinates | `:indexed`, `:indexed_stored`, `:fast`, `:stored`, `:fast_stored` |
| **Bool** | `add_bool_field/3` | Flags, binary states | `:indexed`, `:indexed_stored`, `:fast`, `:stored`, `:fast_stored` |
| **Date** | `add_date_field/3` | Timestamps, publication dates | `:indexed`, `:indexed_stored`, `:fast`, `:stored`, `:fast_stored` |
| **Facet** | `add_facet_field/2` | Categories, hierarchical data | Always indexed and stored |
| **Bytes** | `add_bytes_field/3` | Binary data, hashes, images | `:indexed`, `:indexed_stored`, `:fast`, `:stored`, `:fast_stored` |
| **JSON** | `add_json_field/3` | Structured objects, metadata | `:text`, `:text_stored`, `:stored` |
| **IP Address** | `add_ip_addr_field/3` | IPv4/IPv6 addresses | `:indexed`, `:indexed_stored`, `:fast`, `:stored`, `:fast_stored` |

## Custom Tokenizers

**New in v0.2.0:** TantivyEx now provides comprehensive tokenizer support with advanced text analysis capabilities:

```elixir
# Register default tokenizers (recommended starting point)
TantivyEx.Tokenizer.register_default_tokenizers()

# Create custom text analyzers with advanced processing
TantivyEx.Tokenizer.register_text_analyzer(
  "english_full",
  "simple",           # base tokenizer
  true,               # lowercase
  "english",          # stop words language
  "english",          # stemming language
  50                  # remove tokens longer than 50 chars
)

# Register specialized tokenizers for different use cases
TantivyEx.Tokenizer.register_regex_tokenizer("email", "\\b[\\w._%+-]+@[\\w.-]+\\.[A-Z|a-z]{2,}\\b")
TantivyEx.Tokenizer.register_ngram_tokenizer("fuzzy_search", 2, 4, false)

# Add fields with specific tokenizers
schema = TantivyEx.Schema.new()
|> TantivyEx.Schema.add_text_field_with_tokenizer("content", :text, "english_full")
|> TantivyEx.Schema.add_text_field_with_tokenizer("product_code", :text_stored, "simple")
|> TantivyEx.Schema.add_text_field_with_tokenizer("tags", :text, "whitespace")
```

### Available Tokenizer Types

- **Simple Tokenizer**: Basic punctuation and whitespace splitting with lowercase normalization
- **Whitespace Tokenizer**: Splits only on whitespace, preserves case and punctuation
- **Regex Tokenizer**: Custom pattern-based tokenization for specialized formats
- **N-gram Tokenizer**: Character or word n-grams for fuzzy search and autocomplete
- **Text Analyzer**: Advanced processing with configurable filters (stemming, stop words, case normalization)

### Multi-Language Support

Built-in support for 17+ languages with language-specific stemming and stop words:

```elixir
# Language-specific analyzers
TantivyEx.Tokenizer.register_language_analyzer("english")  # -> "english_text"
TantivyEx.Tokenizer.register_language_analyzer("french")   # -> "french_text"
TantivyEx.Tokenizer.register_language_analyzer("german")   # -> "german_text"

# Or just stemming
TantivyEx.Tokenizer.register_stemming_tokenizer("spanish") # -> "spanish_stem"
```

**Supported languages**: English, French, German, Spanish, Italian, Portuguese, Russian, Arabic, Danish, Dutch, Finnish, Greek, Hungarian, Norwegian, Romanian, Swedish, Tamil, Turkish

## Performance Tips

1. **Use appropriate field options**: Only index fields you need to search
2. **Leverage fast fields**: Use `:fast` for sorting and aggregations
3. **Batch operations**: Commit documents in batches for better performance
4. **Memory management**: Tune writer memory budget based on your use case
5. **Choose optimal tokenizers**: Match tokenizers to your search requirements
   - Use `"default"` for natural language content with stemming
   - Use `"simple"` for structured data like product codes
   - Use `"whitespace"` for tag fields and technical terms
   - Use `"keyword"` for exact matching fields
6. **Language-specific optimization**: Use language analyzers for better search quality
7. **Register tokenizers once**: Call `register_default_tokenizers()` at application startup
8. **Distributed search optimization**:
   - Weight nodes based on their actual capacity
   - Use `"score_desc"` merge strategy for best relevance
   - Monitor cluster health and adjust timeouts accordingly
   - Consider `"health_based"` load balancing for production environments

## Examples

### E-commerce Search

```elixir
# Product search schema
schema = TantivyEx.Schema.new()
|> TantivyEx.Schema.add_text_field("name", :text_stored)
|> TantivyEx.Schema.add_text_field("description", :text)
|> TantivyEx.Schema.add_f64_field("price", :fast_stored)
|> TantivyEx.Schema.add_facet_field("category")
|> TantivyEx.Schema.add_bool_field("in_stock", :fast)
|> TantivyEx.Schema.add_u64_field("product_id", :indexed_stored)
```

### Blog Search

```elixir
# Setup tokenizers for blog content
TantivyEx.Tokenizer.register_default_tokenizers()
TantivyEx.Tokenizer.register_language_analyzer("english")

# Blog post schema with optimized tokenizers
schema = TantivyEx.Schema.new()
|> TantivyEx.Schema.add_text_field_with_tokenizer("title", :text_stored, "english_text")
|> TantivyEx.Schema.add_text_field_with_tokenizer("content", :text, "english_text")
|> TantivyEx.Schema.add_text_field_with_tokenizer("tags", :text_stored, "whitespace")
|> TantivyEx.Schema.add_date_field("published_at", :fast_stored)
|> TantivyEx.Schema.add_u64_field("author_id", :fast)
```

### Log Analysis

```elixir
# Application log schema
schema = TantivyEx.Schema.new()
|> TantivyEx.Schema.add_text_field("message", :text_stored)
|> TantivyEx.Schema.add_text_field("level", :text)
|> TantivyEx.Schema.add_ip_addr_field("client_ip", :indexed_stored)
|> TantivyEx.Schema.add_date_field("timestamp", :fast_stored)
|> TantivyEx.Schema.add_json_field("metadata", :stored)
```

### Distributed Search Setup

```elixir
# Multi-node search coordinator for horizontal scaling
{:ok, _supervisor_pid} = TantivyEx.Distributed.OTP.start_link()

# Add nodes with different weights based on capacity
:ok = TantivyEx.Distributed.OTP.add_node("primary", "http://search1:9200", 2.0)
:ok = TantivyEx.Distributed.OTP.add_node("secondary", "http://search2:9200", 1.5)
:ok = TantivyEx.Distributed.OTP.add_node("backup", "http://search3:9200", 1.0)

# Configure for production use
:ok = TantivyEx.Distributed.OTP.configure(%{
  timeout_ms: 10_000,
  max_retries: 3,
  merge_strategy: :score_desc
})

# Perform distributed search
{:ok, results} = TantivyEx.Distributed.OTP.search("search query", 50, 0)

# Monitor cluster health
{:ok, cluster_stats} = TantivyEx.Distributed.OTP.get_cluster_stats()
IO.puts("Active nodes: #{cluster_stats.active_nodes}/#{cluster_stats.total_nodes}")
```

### Development Setup

```bash
git clone https://github.com/alexiob/tantivy_ex.git
cd tantivy_ex
mix deps.get
mix test
```

## License

TantivyEx is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.

## Acknowledgments

- **[Tantivy](https://github.com/quickwit-oss/tantivy)**: The powerful Rust search engine that powers TantivyEx
- **[Rustler](https://github.com/rusterlium/rustler)**: For excellent Rust-Elixir integration
