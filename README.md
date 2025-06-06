# TantivyEx

[![Elixir CI](https://github.com/your-org/tantivy_ex/workflows/Elixir%20CI/badge.svg)](https://github.com/your-org/tantivy_ex/actions)
[![Hex Version](https://img.shields.io/hexpm/v/tantivy_ex.svg)](https://hex.pm/packages/tantivy_ex)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/tantivy_ex/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

**A comprehensive Elixir wrapper for the Tantivy full-text search engine.**

TantivyEx provides a complete, type-safe interface to Tantivy - Rust's fastest full-text search library. Build powerful search applications with support for all Tantivy field types, custom tokenizers, schema introspection, and advanced indexing features.

## Features

- 🚀 **High Performance**: Built on Tantivy, one of the fastest search engines available
- 📝 **Complete Field Type Support**: Text, numeric, boolean, date, facet, bytes, JSON, and IP address fields
- 🔍 **Advanced Text Processing**: Custom tokenizers, stemming, stop words, and more
- 🏗️ **Schema Management**: Dynamic schema building with validation and introspection
- 💾 **Flexible Storage**: In-memory or persistent disk-based indexes
- 🔧 **Type Safety**: Full Elixir typespecs and compile-time safety
- 📊 **Search Features**: Full-text search, faceted search, range queries, and aggregations

## Quick Start

```elixir
# Create a schema
schema = TantivyEx.Schema.new()
|> TantivyEx.Schema.add_text_field("title", :text_stored)
|> TantivyEx.Schema.add_text_field("body", :text)
|> TantivyEx.Schema.add_u64_field("id", :indexed_stored)
|> TantivyEx.Schema.add_date_field("published_at", :fast)

# Create an index
{:ok, index} = TantivyEx.create_index_in_ram(schema)

# Get a writer
{:ok, writer} = TantivyEx.writer(index, 50_000_000)

# Add documents
doc = %{
  "title" => "Getting Started with TantivyEx",
  "body" => "This is a comprehensive guide to using TantivyEx...",
  "id" => 1,
  "published_at" => "2024-01-15T10:30:00Z"
}

:ok = TantivyEx.add_document(writer, doc)
:ok = TantivyEx.commit(writer)

# Search
{:ok, searcher} = TantivyEx.reader(index)
results = TantivyEx.search(searcher, "comprehensive guide", 10)
```

## Installation

Add `tantivy_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tantivy_ex, "~> 0.1.0"}
  ]
end
```

TantivyEx requires:

- **Elixir**: 1.18 or later
- **Rust**: 1.70 or later (for compilation)
- **System**: Compatible with Linux, macOS, and Windows

## Documentation

### Core Concepts

- **[Schema Guide](guides/schema.md)**: Learn about field types, options, and schema design
- **[Indexing Guide](guides/indexing.md)**: Document indexing, updates, and batch operations
- **[Search Guide](guides/search.md)**: Query types, ranking, and search best practices
- **[Tokenizers Guide](guides/tokenizers.md)**: Text analysis, custom tokenizers, and language support

### API Reference

- **[TantivyEx](https://hexdocs.pm/tantivy_ex/TantivyEx.html)**: Main module with index operations
- **[TantivyEx.Schema](https://hexdocs.pm/tantivy_ex/TantivyEx.Schema.html)**: Schema definition and management
- **[TantivyEx.Native](https://hexdocs.pm/tantivy_ex/TantivyEx.Native.html)**: Low-level NIF functions

## Field Types

TantivyEx supports all Tantivy field types with comprehensive options:

| Field Type | Elixir Function | Use Cases | Options |
|------------|----------------|-----------|---------|
| **Text** | `add_text_field/3` | Full-text search, titles, content | `:text`, `:text_stored`, `:stored` |
| **U64** | `add_u64_field/3` | IDs, counts, timestamps | `:indexed`, `:indexed_stored`, `:fast`, `:stored` |
| **I64** | `add_i64_field/3` | Signed integers, deltas | `:indexed`, `:indexed_stored`, `:fast`, `:stored` |
| **F64** | `add_f64_field/3` | Prices, scores, coordinates | `:indexed`, `:indexed_stored`, `:fast`, `:stored` |
| **Bool** | `add_bool_field/3` | Flags, binary states | `:indexed`, `:indexed_stored`, `:fast`, `:stored` |
| **Date** | `add_date_field/3` | Timestamps, publication dates | `:indexed`, `:indexed_stored`, `:fast`, `:stored` |
| **Facet** | `add_facet_field/2` | Categories, hierarchical data | Always indexed and stored |
| **Bytes** | `add_bytes_field/3` | Binary data, hashes, images | `:indexed`, `:indexed_stored`, `:fast`, `:stored` |
| **JSON** | `add_json_field/3` | Structured objects, metadata | `:indexed`, `:stored` |
| **IP Address** | `add_ip_addr_field/3` | IPv4/IPv6 addresses | `:indexed`, `:indexed_stored`, `:fast`, `:stored` |

## Custom Tokenizers

TantivyEx supports custom tokenizers for advanced text processing:

```elixir
# Add a field with a custom tokenizer
schema = TantivyEx.Schema.new()
|> TantivyEx.Schema.add_text_field_with_tokenizer("content", :text, "en_stem")
|> TantivyEx.Schema.add_text_field_with_tokenizer("ngram_search", :text, "ngram_3")

# Built-in tokenizers: "default", "raw", "en_stem", "whitespace"
# Custom tokenizers can be registered with the index's TokenizerManager
```

## Performance Tips

1. **Use appropriate field options**: Only index fields you need to search
2. **Leverage fast fields**: Use `:fast` for sorting and aggregations
3. **Batch operations**: Commit documents in batches for better performance
4. **Memory management**: Tune writer memory budget based on your use case
5. **Custom tokenizers**: Choose tokenizers that match your search requirements

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
# Blog post schema with custom tokenizers
schema = TantivyEx.Schema.new()
|> TantivyEx.Schema.add_text_field_with_tokenizer("title", :text_stored, "en_stem")
|> TantivyEx.Schema.add_text_field_with_tokenizer("content", :text, "en_stem")
|> TantivyEx.Schema.add_text_field("tags", :text_stored)
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

## Contributing

We welcome contributions! Please see [DEVELOPMENT.md](DEVELOPMENT.md) for development setup and guidelines.

### Development Setup

```bash
git clone https://github.com/your-org/tantivy_ex.git
cd tantivy_ex
mix deps.get
mix test
```

## License

TantivyEx is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.

## Acknowledgments

- **[Tantivy](https://github.com/quickwit-oss/tantivy)**: The powerful Rust search engine that powers TantivyEx
- **[Rustler](https://github.com/rusterlium/rustler)**: For excellent Rust-Elixir integration
- **Elixir Community**: For inspiration and feedback

---

**Ready to build powerful search applications?** Check out our [guides](guides/) and start searching! 🔍
