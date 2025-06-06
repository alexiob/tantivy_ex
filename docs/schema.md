# Schema Design Guide

This guide covers schema design principles and field types in TantivyEx.

## Table of Contents

- [Schema Basics](#schema-basics)
- [Field Types Reference](#field-types-reference)
- [Schema Design Patterns](#schema-design-patterns)
- [Performance Considerations](#performance-considerations)
- [Migration Strategies](#migration-strategies)

## Schema Basics

A schema defines the structure of your documents and how they should be indexed. In TantivyEx, you create a schema by adding fields with specific types and options.

### Creating a Schema

```elixir
alias TantivyEx.Schema

# Create a new schema
{:ok, schema} = Schema.new()

# Add fields to the schema
{:ok, schema} = Schema.add_text_field(schema, "title", :TEXT_STORED)
{:ok, schema} = Schema.add_text_field(schema, "body", :TEXT)
{:ok, schema} = Schema.add_u64_field(schema, "timestamp", :INDEXED)
{:ok, schema} = Schema.add_f64_field(schema, "price", :INDEXED)
```

### Schema Introspection

```elixir
# Get all field names
{:ok, fields} = Schema.get_field_names(schema)
# Returns: ["title", "body", "timestamp", "price"]

# Get specific field information
{:ok, field_info} = Schema.get_field_info(schema, "title")
# Returns: %{name: "title", type: "text", options: ["indexed", "stored"]}
```

## Field Types Reference

### Text Fields

Text fields are used for full-text search and support various indexing options.

#### Options

- `:TEXT` - Indexed for search only
- `:TEXT_STORED` - Indexed and stored (retrievable)
- `:STORED` - Stored only (not searchable)

#### Examples

```elixir
# Full-text searchable title that can be retrieved
{:ok, schema} = Schema.add_text_field(schema, "title", :TEXT_STORED)

# Full-text searchable content (not stored to save space)
{:ok, schema} = Schema.add_text_field(schema, "content", :TEXT)

# Metadata that's stored but not searchable
{:ok, schema} = Schema.add_text_field(schema, "metadata", :STORED)
```

#### With Custom Tokenizers

```elixir
# Use simple tokenizer for exact matching
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema,
  "product_code",
  :TEXT_STORED,
  "simple"
)

# Use whitespace tokenizer for basic word splitting
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema,
  "tags",
  :TEXT,
  "whitespace"
)
```

### Numeric Fields

Numeric fields support range queries and sorting.

#### U64 Fields (Unsigned 64-bit integers)

```elixir
# Indexed timestamp for range queries
{:ok, schema} = Schema.add_u64_field(schema, "created_at", :INDEXED)

# Stored and indexed user ID
{:ok, schema} = Schema.add_u64_field(schema, "user_id", :INDEXED_STORED)

# Stored-only view count (not queryable)
{:ok, schema} = Schema.add_u64_field(schema, "view_count", :STORED)
```

#### I64 Fields (Signed 64-bit integers)

```elixir
# Temperature readings (can be negative)
{:ok, schema} = Schema.add_i64_field(schema, "temperature", :INDEXED)

# Profit/loss calculations
{:ok, schema} = Schema.add_i64_field(schema, "profit", :INDEXED_STORED)
```

#### F64 Fields (64-bit floating point)

```elixir
# Product prices for range filtering
{:ok, schema} = Schema.add_f64_field(schema, "price", :INDEXED)

# Geographic coordinates
{:ok, schema} = Schema.add_f64_field(schema, "latitude", :INDEXED_STORED)
{:ok, schema} = Schema.add_f64_field(schema, "longitude", :INDEXED_STORED)

# Rating scores
{:ok, schema} = Schema.add_f64_field(schema, "rating", :INDEXED)
```

### Binary Fields

Binary fields store arbitrary byte data.

```elixir
# Store file content
{:ok, schema} = Schema.add_bytes_field(schema, "file_data", :STORED)

# Store and index binary checksums
{:ok, schema} = Schema.add_bytes_field(schema, "checksum", :INDEXED_STORED)
```

### Date Fields

Date fields provide optimized date/time handling.

```elixir
# Article publication date
{:ok, schema} = Schema.add_date_field(schema, "published_at", :INDEXED)

# User registration with storage
{:ok, schema} = Schema.add_date_field(schema, "registered_at", :INDEXED_STORED)
```

### JSON Fields

JSON fields store structured data as JSON objects.

```elixir
# Store user preferences
{:ok, schema} = Schema.add_json_field(schema, "preferences", :STORED)

# Store and index configuration
{:ok, schema} = Schema.add_json_field(schema, "config", :INDEXED_STORED)
```

### IP Address Fields

Specialized fields for IPv4 and IPv6 addresses.

```elixir
# Client IP addresses
{:ok, schema} = Schema.add_ip_addr_field(schema, "client_ip", :INDEXED)

# Server addresses with storage
{:ok, schema} = Schema.add_ip_addr_field(schema, "server_ip", :INDEXED_STORED)
```

### Facet Fields

Facet fields enable hierarchical categorization and faceted search.

```elixir
# Product categories (e.g., "/electronics/phones/smartphones")
{:ok, schema} = Schema.add_facet_field(schema, "category", :INDEXED)

# Geographic hierarchy with storage
{:ok, schema} = Schema.add_facet_field(schema, "location", :INDEXED_STORED)
```

## Schema Design Patterns

### E-commerce Product Catalog

```elixir
{:ok, schema} = Schema.new()

# Basic product information
{:ok, schema} = Schema.add_text_field(schema, "name", :TEXT_STORED)
{:ok, schema} = Schema.add_text_field(schema, "description", :TEXT)
{:ok, schema} = Schema.add_text_field(schema, "brand", :TEXT_STORED)

# Pricing and inventory
{:ok, schema} = Schema.add_f64_field(schema, "price", :INDEXED)
{:ok, schema} = Schema.add_u64_field(schema, "stock_quantity", :INDEXED)

# Categories and attributes
{:ok, schema} = Schema.add_facet_field(schema, "category", :INDEXED)
{:ok, schema} = Schema.add_json_field(schema, "attributes", :STORED)

# Ratings and reviews
{:ok, schema} = Schema.add_f64_field(schema, "average_rating", :INDEXED)
{:ok, schema} = Schema.add_u64_field(schema, "review_count", :INDEXED)

# Metadata
{:ok, schema} = Schema.add_date_field(schema, "created_at", :INDEXED)
{:ok, schema} = Schema.add_date_field(schema, "updated_at", :INDEXED)
```

### Blog/CMS System

```elixir
{:ok, schema} = Schema.new()

# Content fields
{:ok, schema} = Schema.add_text_field(schema, "title", :TEXT_STORED)
{:ok, schema} = Schema.add_text_field(schema, "content", :TEXT)
{:ok, schema} = Schema.add_text_field(schema, "excerpt", :TEXT_STORED)
{:ok, schema} = Schema.add_text_field(schema, "slug", :STORED)

# Author information
{:ok, schema} = Schema.add_text_field(schema, "author_name", :TEXT_STORED)
{:ok, schema} = Schema.add_u64_field(schema, "author_id", :INDEXED)

# Categorization
{:ok, schema} = Schema.add_facet_field(schema, "category", :INDEXED)
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema, "tags", :TEXT, "whitespace"
)

# Publishing workflow
{:ok, schema} = Schema.add_text_field(schema, "status", :INDEXED)
{:ok, schema} = Schema.add_date_field(schema, "published_at", :INDEXED)
{:ok, schema} = Schema.add_date_field(schema, "created_at", :INDEXED)
```

### Log Analysis System

```elixir
{:ok, schema} = Schema.new()

# Log entry basics
{:ok, schema} = Schema.add_text_field(schema, "message", :TEXT)
{:ok, schema} = Schema.add_text_field(schema, "level", :INDEXED)
{:ok, schema} = Schema.add_date_field(schema, "timestamp", :INDEXED)

# Source information
{:ok, schema} = Schema.add_text_field(schema, "service", :INDEXED)
{:ok, schema} = Schema.add_text_field(schema, "host", :INDEXED)
{:ok, schema} = Schema.add_ip_addr_field(schema, "client_ip", :INDEXED)

# Structured data
{:ok, schema} = Schema.add_json_field(schema, "metadata", :STORED)
{:ok, schema} = Schema.add_u64_field(schema, "request_id", :INDEXED)

# Performance metrics
{:ok, schema} = Schema.add_f64_field(schema, "response_time", :INDEXED)
{:ok, schema} = Schema.add_u64_field(schema, "status_code", :INDEXED)
```

## Performance Considerations

### Field Storage Strategy

**Store only what you need to retrieve:**

- Use `:TEXT` instead of `:TEXT_STORED` for large content that you don't need to display
- Store frequently accessed fields for better retrieval performance
- Consider the trade-off between index size and retrieval speed

**Example:**

```elixir
# Good: Store title for display, don't store body (search only)
{:ok, schema} = Schema.add_text_field(schema, "title", :TEXT_STORED)
{:ok, schema} = Schema.add_text_field(schema, "body", :TEXT)

# Bad: Storing large content unnecessarily
{:ok, schema} = Schema.add_text_field(schema, "body", :TEXT_STORED)  # Bloats index
```

### Indexing Strategy

**Index only queryable fields:**

- Don't index fields that are only used for display
- Use appropriate numeric types for range queries
- Consider facet fields for categorical data

**Example:**

```elixir
# Good: Index searchable and filterable fields
{:ok, schema} = Schema.add_text_field(schema, "searchable_content", :TEXT)
{:ok, schema} = Schema.add_u64_field(schema, "category_id", :INDEXED)
{:ok, schema} = Schema.add_text_field(schema, "display_only", :STORED)

# Bad: Indexing display-only data
{:ok, schema} = Schema.add_text_field(schema, "display_only", :TEXT)  # Wastes space
```

### Tokenizer Selection

Choose tokenizers based on your search requirements:

- **Default**: Good for most text search scenarios
- **Simple**: For exact matching (product codes, IDs)
- **Whitespace**: For tag-like data where punctuation matters
- **Keyword**: For fields that should be treated as single terms

## Migration Strategies

### Schema Evolution

Tantivy schemas are immutable once an index is created. For schema changes:

1. **Create a new index** with the updated schema
2. **Reindex all documents** into the new index
3. **Switch over** to the new index atomically

### Backwards Compatibility

When designing schemas, consider future needs:

```elixir
# Add optional fields that can be null/empty
{:ok, schema} = Schema.add_json_field(schema, "extensions", :STORED)

# Use generic field names for flexibility
{:ok, schema} = Schema.add_f64_field(schema, "metric_1", :INDEXED)
{:ok, schema} = Schema.add_f64_field(schema, "metric_2", :INDEXED)
```

### Data Migration Example

```elixir
defmodule MyApp.IndexMigration do
  alias TantivyEx.{Index, Schema}

  def migrate_to_new_schema(old_index_path, new_index_path) do
    # Create new schema
    {:ok, new_schema} = create_new_schema()

    # Create new index
    {:ok, new_index} = Index.create(new_index_path, new_schema)

    # Read from old index and write to new
    old_docs = read_all_documents(old_index_path)

    Enum.each(old_docs, fn doc ->
      transformed_doc = transform_document(doc)
      Index.add_document(new_index, transformed_doc)
    end)

    Index.commit(new_index)
  end

  defp transform_document(old_doc) do
    # Transform document structure for new schema
    # Handle field renames, type changes, etc.
    old_doc
    |> Map.put("new_field", derive_new_field_value(old_doc))
    |> Map.delete("deprecated_field")
  end
end
```

## Best Practices

1. **Plan ahead**: Design schemas with future requirements in mind
2. **Test with real data**: Validate schema performance with representative datasets
3. **Monitor index size**: Balance between functionality and storage/memory usage
4. **Document your schema**: Keep clear documentation of field purposes and constraints
5. **Use consistent naming**: Follow naming conventions across your application
6. **Consider query patterns**: Design fields to support your most common query types

## Troubleshooting

### Common Schema Issues

**Field not searchable:**

- Ensure the field is indexed (`:TEXT`, `:INDEXED`, etc.)
- Check that the correct tokenizer is used for text fields

**Large index size:**

- Review which fields are stored vs. indexed
- Consider using `:TEXT` instead of `:TEXT_STORED` for large content

**Slow queries:**

- Ensure filtered fields are indexed
- Consider using facet fields for categorical data
- Review tokenizer choice for text fields

**Type mismatches:**

- Ensure document field types match schema definitions
- Use appropriate numeric types (u64 vs. i64 vs. f64)
