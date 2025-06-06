# Schema Design Guide

This comprehensive guide covers schema design principles, field types, and best practices for building efficient search applications with TantivyEx.

## Table of Contents

- [Understanding Schemas](#understanding-schemas)
- [Schema Basics](#schema-basics)
- [Field Types Reference](#field-types-reference)
- [Field Options Deep Dive](#field-options-deep-dive)
- [Schema Design Patterns](#schema-design-patterns)
- [Performance Considerations](#performance-considerations)
- [Common Pitfalls](#common-pitfalls)
- [Migration Strategies](#migration-strategies)
- [Real-World Examples](#real-world-examples)

## Understanding Schemas

### What is a Schema?

A **schema** in TantivyEx is a blueprint that defines:

1. **Document Structure**: What fields your documents contain
2. **Field Types**: How each field's data should be interpreted (text, numbers, dates, etc.)
3. **Indexing Strategy**: How each field should be processed for search
4. **Storage Options**: Whether field values should be retrievable from search results

Think of a schema as a contract between your application and the search engine - it tells TantivyEx exactly how to handle your data for optimal search performance.

### Schema Design Philosophy

When designing a schema, consider these key principles:

- **Search Requirements**: What types of queries will you run?
- **Performance Needs**: What are your speed and memory constraints?
- **Data Characteristics**: What types of data are you working with?
- **Future Growth**: How might your requirements evolve?

## Schema Basics

### Creating a Schema

```elixir
alias TantivyEx.Schema

# Create a new schema
{:ok, schema} = Schema.new()

# Add fields to the schema
{:ok, schema} = Schema.add_text_field(schema, "title", :text_stored)
{:ok, schema} = Schema.add_text_field(schema, "body", :text)
{:ok, schema} = Schema.add_u64_field(schema, "timestamp", :fast_stored)
{:ok, schema} = Schema.add_f64_field(schema, "price", :fast_stored)
{:ok, schema} = Schema.add_facet_field(schema, "category", :facet)
```

### Schema Introspection

```elixir
# Get all field names
{:ok, fields} = Schema.get_field_names(schema)
# Returns: ["title", "body", "timestamp", "price", "category"]

# Get specific field information
{:ok, field_info} = Schema.get_field_info(schema, "title")
# Returns detailed information about the field configuration
```

### Schema Validation

Always validate your schema before creating an index:

```elixir
defmodule MyApp.SchemaValidator do
  def validate_schema(schema) do
    with {:ok, fields} <- Schema.get_field_names(schema),
         :ok <- check_required_fields(fields),
         :ok <- check_field_types(schema, fields) do
      {:ok, schema}
    else
      {:error, reason} -> {:error, "Schema validation failed: #{reason}"}
    end
  end

  defp check_required_fields(fields) do
    required = ["title", "content"]
    missing = required -- fields

    case missing do
      [] -> :ok
      missing_fields -> {:error, "Schema validation failed: Missing required fields: #{inspect(missing_fields)}"}
    end
  end

  defp check_field_types(schema, fields) do
    # Validate that each field has appropriate type for its intended use
    Enum.reduce_while(fields, :ok, fn field, acc ->
      case Schema.get_field_info(schema, field) do
        {:ok, _info} -> {:cont, acc}
        {:error, reason} -> {:halt, {:error, "Invalid field #{field}: #{reason}"}}
      end
    end)
  end
end
```

## Field Types Reference

### Text Fields

Text fields are used for full-text search and support various indexing options.

#### Options

- `:text` - Indexed for search only
- `:text_stored` - Indexed and stored (retrievable)
- `:stored` - Stored only (not searchable)
- `:fast` - Indexed and optimized for fast access
- `:fast_stored` - Indexed with positions for phrase queries, stored, and optimized for fast access

#### Examples

```elixir
# Full-text searchable title that can be retrieved
{:ok, schema} = Schema.add_text_field(schema, "title", :text_stored)

# Full-text searchable content (not stored to save space)
{:ok, schema} = Schema.add_text_field(schema, "content", :text)

# Metadata that's stored but not searchable
{:ok, schema} = Schema.add_text_field(schema, "metadata", :stored)
```

#### With Custom Tokenizers

```elixir
# Use simple tokenizer for exact matching
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema,
  "product_code",
  :text_stored,
  "simple"
)

# Use whitespace tokenizer for basic word splitting
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema,
  "tags",
  :text,
  "whitespace"
)
```

### Numeric Fields

Numeric fields support range queries and sorting.

#### U64 Fields (Unsigned 64-bit integers)

```elixir
# Indexed timestamp for range queries
{:ok, schema} = Schema.add_u64_field(schema, "created_at", :indexed)

# Stored and indexed user ID
{:ok, schema} = Schema.add_u64_field(schema, "user_id", :indexed_stored)

# Stored-only view count (not queryable)
{:ok, schema} = Schema.add_u64_field(schema, "view_count", :stored)
```

#### I64 Fields (Signed 64-bit integers)

```elixir
# Temperature readings (can be negative)
{:ok, schema} = Schema.add_i64_field(schema, "temperature", :indexed)

# Profit/loss calculations
{:ok, schema} = Schema.add_i64_field(schema, "profit", :indexed_stored)
```

#### F64 Fields (64-bit floating point)

```elixir
# Product prices for range filtering
{:ok, schema} = Schema.add_f64_field(schema, "price", :indexed)

# Geographic coordinates
{:ok, schema} = Schema.add_f64_field(schema, "latitude", :indexed_stored)
{:ok, schema} = Schema.add_f64_field(schema, "longitude", :indexed_stored)

# Rating scores
{:ok, schema} = Schema.add_f64_field(schema, "rating", :indexed)
```

### Binary Fields

Binary fields store arbitrary byte data.

```elixir
# Store file content
{:ok, schema} = Schema.add_bytes_field(schema, "file_data", :stored)

# Store and index binary checksums
{:ok, schema} = Schema.add_bytes_field(schema, "checksum", :indexed_stored)
```

### Date Fields

Date fields provide optimized date/time handling.

```elixir
# Article publication date
{:ok, schema} = Schema.add_date_field(schema, "published_at", :indexed)

# User registration with storage
{:ok, schema} = Schema.add_date_field(schema, "registered_at", :indexed_stored)
```

### JSON Fields

JSON fields store structured data as JSON objects.

```elixir
# Store user preferences
{:ok, schema} = Schema.add_json_field(schema, "preferences", :stored)

# Store and index configuration
{:ok, schema} = Schema.add_json_field(schema, "config", :indexed_stored)
```

### IP Address Fields

Specialized fields for IPv4 and IPv6 addresses.

```elixir
# Client IP addresses
{:ok, schema} = Schema.add_ip_addr_field(schema, "client_ip", :indexed)

# Server addresses with storage
{:ok, schema} = Schema.add_ip_addr_field(schema, "server_ip", :indexed_stored)
```

### Facet Fields

Facet fields enable hierarchical categorization and faceted search.

```elixir
# Product categories (e.g., "/electronics/phones/smartphones")
{:ok, schema} = Schema.add_facet_field(schema, "category", :indexed)

# Geographic hierarchy with storage
{:ok, schema} = Schema.add_facet_field(schema, "location", :indexed_stored)
```

## Schema Design Patterns

### E-commerce Product Catalog

```elixir
{:ok, schema} = Schema.new()

# Basic product information
{:ok, schema} = Schema.add_text_field(schema, "name", :text_stored)
{:ok, schema} = Schema.add_text_field(schema, "description", :text)
{:ok, schema} = Schema.add_text_field(schema, "brand", :text_stored)

# Pricing and inventory
{:ok, schema} = Schema.add_f64_field(schema, "price", :indexed)
{:ok, schema} = Schema.add_u64_field(schema, "stock_quantity", :indexed)

# Categories and attributes
{:ok, schema} = Schema.add_facet_field(schema, "category", :indexed)
{:ok, schema} = Schema.add_json_field(schema, "attributes", :stored)

# Ratings and reviews
{:ok, schema} = Schema.add_f64_field(schema, "average_rating", :indexed)
{:ok, schema} = Schema.add_u64_field(schema, "review_count", :indexed)

# Metadata
{:ok, schema} = Schema.add_date_field(schema, "created_at", :indexed)
{:ok, schema} = Schema.add_date_field(schema, "updated_at", :indexed)
```

### Blog/CMS System

```elixir
{:ok, schema} = Schema.new()

# Content fields
{:ok, schema} = Schema.add_text_field(schema, "title", :text_stored)
{:ok, schema} = Schema.add_text_field(schema, "content", :text)
{:ok, schema} = Schema.add_text_field(schema, "excerpt", :text_stored)
{:ok, schema} = Schema.add_text_field(schema, "slug", :stored)

# Author information
{:ok, schema} = Schema.add_text_field(schema, "author_name", :text_stored)
{:ok, schema} = Schema.add_u64_field(schema, "author_id", :indexed)

# Categorization
{:ok, schema} = Schema.add_facet_field(schema, "category", :indexed)
{:ok, schema} = Schema.add_text_field_with_tokenizer(
  schema, "tags", :text, "whitespace"
)

# Publishing workflow
{:ok, schema} = Schema.add_text_field(schema, "status", :indexed)
{:ok, schema} = Schema.add_date_field(schema, "published_at", :indexed)
{:ok, schema} = Schema.add_date_field(schema, "created_at", :indexed)
```

### Log Analysis System

```elixir
{:ok, schema} = Schema.new()

# Log entry basics
{:ok, schema} = Schema.add_text_field(schema, "message", :text)
{:ok, schema} = Schema.add_text_field(schema, "level", :indexed)
{:ok, schema} = Schema.add_date_field(schema, "timestamp", :indexed)

# Source information
{:ok, schema} = Schema.add_text_field(schema, "service", :indexed)
{:ok, schema} = Schema.add_text_field(schema, "host", :indexed)
{:ok, schema} = Schema.add_ip_addr_field(schema, "client_ip", :indexed)

# Structured data
{:ok, schema} = Schema.add_json_field(schema, "metadata", :stored)
{:ok, schema} = Schema.add_u64_field(schema, "request_id", :indexed)

# Performance metrics
{:ok, schema} = Schema.add_f64_field(schema, "response_time", :indexed)
{:ok, schema} = Schema.add_u64_field(schema, "status_code", :indexed)
```

## Performance Considerations

### Field Storage Strategy

**Store only what you need to retrieve:**

- Use `:text` instead of `:text_stored` for large content that you don't need to display
- Store frequently accessed fields for better retrieval performance
- Consider the trade-off between index size and retrieval speed

**Example:**

```elixir
# Good: Store title for display, don't store body (search only)
{:ok, schema} = Schema.add_text_field(schema, "title", :text_stored)
{:ok, schema} = Schema.add_text_field(schema, "body", :text)

# Bad: Storing large content unnecessarily
{:ok, schema} = Schema.add_text_field(schema, "body", :text_stored)  # Bloats index
```

### Indexing Strategy

**Index only queryable fields:**

- Don't index fields that are only used for display
- Use appropriate numeric types for range queries
- Consider facet fields for categorical data

**Example:**

```elixir
# Good: Index searchable and filterable fields
{:ok, schema} = Schema.add_text_field(schema, "searchable_content", :text)
{:ok, schema} = Schema.add_u64_field(schema, "category_id", :indexed)
{:ok, schema} = Schema.add_text_field(schema, "display_only", :stored)

# Bad: Indexing display-only data
{:ok, schema} = Schema.add_text_field(schema, "display_only", :text)  # Wastes space
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
{:ok, schema} = Schema.add_json_field(schema, "extensions", :stored)

# Use generic field names for flexibility
{:ok, schema} = Schema.add_f64_field(schema, "metric_1", :indexed)
{:ok, schema} = Schema.add_f64_field(schema, "metric_2", :indexed)
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

- Ensure the field is indexed (`:text`, `:indexed`, etc.)
- Check that the correct tokenizer is used for text fields

**Large index size:**

- Review which fields are stored vs. indexed
- Consider using `:text` instead of `:text_stored` for large content

**Slow queries:**

- Ensure filtered fields are indexed
- Consider using facet fields for categorical data
- Review tokenizer choice for text fields

**Type mismatches:**

- Ensure document field types match schema definitions
- Use appropriate numeric types (u64 vs. i64 vs. f64)

## Field Options Deep Dive

Understanding field options is crucial for optimal performance and functionality. Each option serves specific use cases and has performance implications.

### Text Field Options Explained

#### `:text` - Search Only

- **Use case**: Large content fields (article body, descriptions)
- **Storage**: Not stored in index (saves space)
- **Searchable**: Yes (full-text search)
- **Retrievable**: No
- **Performance**: Fastest indexing, smallest index size

```elixir
# Perfect for large content you only need to search
{:ok, schema} = Schema.add_text_field(schema, "article_content", :text)
```

#### `:text_stored` - Search and Retrieve

- **Use case**: Titles, names, short descriptions
- **Storage**: Stored in index
- **Searchable**: Yes (full-text search)
- **Retrievable**: Yes
- **Performance**: Larger index size, retrieval without external lookup

```elixir
# Perfect for fields you need in search results
{:ok, schema} = Schema.add_text_field(schema, "title", :text_stored)
```

#### `:stored` - Storage Only

- **Use case**: Metadata, IDs, non-searchable data
- **Storage**: Stored in index
- **Searchable**: No
- **Retrievable**: Yes
- **Performance**: Minimal indexing overhead

```elixir
# Perfect for display-only data
{:ok, schema} = Schema.add_text_field(schema, "internal_id", :stored)
```

#### `:fast` - Optimized Access

- **Use case**: Fields used in sorting, faceting, or frequent filtering
- **Storage**: Not stored (saves space)
- **Searchable**: Yes (term queries, not full-text)
- **Retrievable**: No
- **Performance**: Fast random access, optimized for aggregations

```elixir
# Perfect for categorical data used in filters
{:ok, schema} = Schema.add_text_field(schema, "status", :fast)
```

#### `:fast_stored` - Complete Functionality

- **Use case**: Fields needing full functionality (search, retrieve, sort, phrase queries)
- **Storage**: Stored with position information
- **Searchable**: Yes (full-text with phrase queries)
- **Retrievable**: Yes
- **Performance**: Largest index size, most functionality

```elixir
# Perfect for important fields needing all features
{:ok, schema} = Schema.add_text_field(schema, "product_name", :fast_stored)
```

### Numeric Field Options

#### `:indexed` - Basic Indexing

- **Use case**: Range queries, basic filtering
- **Functionality**: Range queries (`field:[10 TO 20]`)
- **Storage**: Not stored
- **Performance**: Good for filtering, can't retrieve values

#### `:fast` - Optimized Performance

- **Use case**: High-performance filtering, sorting, aggregations
- **Functionality**: Very fast range queries, sorting
- **Storage**: Not stored
- **Performance**: Optimized data structure, fastest queries

#### `:stored` - Storage Only

- **Use case**: Display values without querying capability
- **Functionality**: Retrieval only
- **Storage**: Stored
- **Performance**: No query performance impact

#### `:fast_stored` - Complete Functionality

- **Use case**: Fields needing both fast queries and value retrieval
- **Functionality**: Fast queries + value retrieval
- **Storage**: Stored with fast access
- **Performance**: Best of both worlds, larger index

### Field Option Decision Matrix

| Need to... | Text Option | Numeric Option |
|------------|-------------|----------------|
| Search only | `:text` | `:indexed` |
| Search + retrieve | `:text_stored` | `:indexed_stored` |
| Fast operations only | `:fast` | `:fast` |
| Everything | `:fast_stored` | `:fast_stored` |
| Store only | `:stored` | `:stored` |

## Common Pitfalls

### 1. Over-storing Data

**Problem**: Storing every field makes indexes unnecessarily large.

```elixir
# ❌ Bad: Storing large content unnecessarily
{:ok, schema} = Schema.add_text_field(schema, "full_article", :text_stored)

# ✅ Good: Store summary, search full content
{:ok, schema} = Schema.add_text_field(schema, "full_article", :text)
{:ok, schema} = Schema.add_text_field(schema, "summary", :text_stored)
```

### 2. Wrong Field Types for Data

**Problem**: Using text fields for structured data that should be numeric or faceted.

```elixir
# ❌ Bad: String for numeric data
{:ok, schema} = Schema.add_text_field(schema, "price", :text_stored)

# ✅ Good: Proper numeric type
{:ok, schema} = Schema.add_f64_field(schema, "price", :fast_stored)

# ❌ Bad: Text for categories
{:ok, schema} = Schema.add_text_field(schema, "category", :text)

# ✅ Good: Facet for hierarchical categories
{:ok, schema} = Schema.add_facet_field(schema, "category", :facet)
```

### 3. Inadequate Field Options

**Problem**: Choosing field options that don't support your query patterns.

```elixir
# ❌ Bad: Can't do phrase queries
{:ok, schema} = Schema.add_text_field(schema, "title", :text_stored)

# If you need phrase queries ("exact phrase"), use:
# ✅ Good: Supports phrase queries
{:ok, schema} = Schema.add_text_field(schema, "title", :fast_stored)
```

### 4. Inconsistent Field Naming

**Problem**: Inconsistent naming makes code harder to maintain.

```elixir
# ❌ Bad: Inconsistent naming
{:ok, schema} = Schema.add_text_field(schema, "Title", :text_stored)
{:ok, schema} = Schema.add_text_field(schema, "article_content", :text)
{:ok, schema} = Schema.add_u64_field(schema, "created", :indexed)

# ✅ Good: Consistent naming convention
{:ok, schema} = Schema.add_text_field(schema, "title", :text_stored)
{:ok, schema} = Schema.add_text_field(schema, "content", :text)
{:ok, schema} = Schema.add_u64_field(schema, "created_at", :indexed)
```

### 5. Missing Required Fields

**Problem**: Forgetting fields needed for core functionality.

```elixir
# ✅ Always include essential fields
defmodule MyApp.SchemaBuilder do
  def build_schema do
    {:ok, schema} = Schema.new()

    # Core searchable content
    {:ok, schema} = Schema.add_text_field(schema, "title", :text_stored)
    {:ok, schema} = Schema.add_text_field(schema, "content", :text)

    # Essential metadata
    {:ok, schema} = Schema.add_u64_field(schema, "created_at", :fast_stored)
    {:ok, schema} = Schema.add_u64_field(schema, "updated_at", :fast_stored)

    # Unique identifier (always store)
    {:ok, schema} = Schema.add_text_field(schema, "id", :stored)

    {:ok, schema}
  end
end
```

## Real-World Examples

### E-commerce Search Engine

This example shows a comprehensive e-commerce product search schema:

```elixir
defmodule EcommerceSchema do
  alias TantivyEx.Schema

  def create_product_schema do
    {:ok, schema} = Schema.new()

    # Product identification and basic info
    {:ok, schema} = Schema.add_text_field(schema, "id", :stored)
    {:ok, schema} = Schema.add_text_field(schema, "sku", :text_stored)
    {:ok, schema} = Schema.add_text_field(schema, "name", :fast_stored)  # Phrase queries for exact names
    {:ok, schema} = Schema.add_text_field(schema, "description", :text)  # Search only, save space

    # Brand and manufacturer
    {:ok, schema} = Schema.add_text_field(schema, "brand", :fast_stored)  # Fast filtering + display
    {:ok, schema} = Schema.add_text_field(schema, "manufacturer", :text_stored)

    # Pricing and inventory
    {:ok, schema} = Schema.add_f64_field(schema, "price", :fast_stored)  # Range queries + display
    {:ok, schema} = Schema.add_f64_field(schema, "sale_price", :fast_stored)
    {:ok, schema} = Schema.add_u64_field(schema, "stock_quantity", :fast)  # Fast filtering
    {:ok, schema} = Schema.add_text_field(schema, "availability", :fast)  # in_stock, out_of_stock, etc.

    # Categories and classification
    {:ok, schema} = Schema.add_facet_field(schema, "category", :facet)  # /electronics/phones/smartphones
    {:ok, schema} = Schema.add_facet_field(schema, "department", :facet)  # /men/clothing/shirts
    {:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "tags", :text, "whitespace")

    # Product attributes (color, size, etc.)
    {:ok, schema} = Schema.add_json_field(schema, "attributes", :stored)  # Flexible storage
    {:ok, schema} = Schema.add_text_field(schema, "color", :fast)  # Fast filtering
    {:ok, schema} = Schema.add_text_field(schema, "size", :fast)
    {:ok, schema} = Schema.add_text_field(schema, "material", :text_stored)

    # Ratings and reviews
    {:ok, schema} = Schema.add_f64_field(schema, "average_rating", :fast_stored)
    {:ok, schema} = Schema.add_u64_field(schema, "review_count", :fast_stored)
    {:ok, schema} = Schema.add_u64_field(schema, "five_star_count", :fast)

    # SEO and metadata
    {:ok, schema} = Schema.add_text_field(schema, "meta_title", :stored)
    {:ok, schema} = Schema.add_text_field(schema, "meta_description", :stored)
    {:ok, schema} = Schema.add_text_field(schema, "url_slug", :stored)

    # Timestamps and versioning
    {:ok, schema} = Schema.add_date_field(schema, "created_at", :fast_stored)
    {:ok, schema} = Schema.add_date_field(schema, "updated_at", :fast_stored)
    {:ok, schema} = Schema.add_date_field(schema, "published_at", :fast)

    # Sales and popularity metrics
    {:ok, schema} = Schema.add_u64_field(schema, "sales_count", :fast)
    {:ok, schema} = Schema.add_u64_field(schema, "view_count", :fast)
    {:ok, schema} = Schema.add_f64_field(schema, "popularity_score", :fast)

    {:ok, schema}
  end

  # Example usage
  def search_products(index, query_params) do
    query = build_search_query(query_params)
    TantivyEx.Index.search(index, query, 50)
  end

  defp build_search_query(%{
    text: text,
    brand: brand,
    category: category,
    min_price: min_price,
    max_price: max_price,
    min_rating: min_rating
  }) do
    parts = []

    # Text search in name and description
    if text && text != "" do
      parts = ["(name:#{text} OR description:#{text})" | parts]
    end

    # Brand filter
    if brand && brand != "" do
      parts = ["brand:\"#{brand}\"" | parts]
    end

    # Category filter (facet)
    if category && category != "" do
      parts = ["category:\"#{category}\"" | parts]
    end

    # Price range
    if min_price || max_price do
      min_val = min_price || "*"
      max_val = max_price || "*"
      parts = ["price:[#{min_val} TO #{max_val}]" | parts]
    end

    # Rating filter
    if min_rating do
      parts = ["average_rating:[#{min_rating} TO *]" | parts]
    end

    # Combine with AND
    Enum.join(parts, " AND ")
  end
end
```

### Document Management System

This example shows a schema for a legal document management system:

```elixir
defmodule DocumentManagementSchema do
  alias TantivyEx.Schema

  def create_document_schema do
    {:ok, schema} = Schema.new()

    # Document identification
    {:ok, schema} = Schema.add_text_field(schema, "id", :stored)
    {:ok, schema} = Schema.add_text_field(schema, "document_number", :text_stored)
    {:ok, schema} = Schema.add_text_field(schema, "title", :fast_stored)

    # Content fields
    {:ok, schema} = Schema.add_text_field(schema, "content", :text)  # Full-text search only
    {:ok, schema} = Schema.add_text_field(schema, "summary", :text_stored)  # Display summary
    {:ok, schema} = Schema.add_text_field(schema, "abstract", :text_stored)

    # Document classification
    {:ok, schema} = Schema.add_facet_field(schema, "document_type", :facet)  # /legal/contracts/employment
    {:ok, schema} = Schema.add_facet_field(schema, "practice_area", :facet)  # /corporate/mergers
    {:ok, schema} = Schema.add_text_field(schema, "subject_matter", :text_stored)

    # Legal-specific fields
    {:ok, schema} = Schema.add_text_field(schema, "jurisdiction", :fast_stored)
    {:ok, schema} = Schema.add_text_field(schema, "court", :text_stored)
    {:ok, schema} = Schema.add_text_field(schema, "case_number", :text_stored)
    {:ok, schema} = Schema.add_date_field(schema, "filing_date", :fast_stored)
    {:ok, schema} = Schema.add_date_field(schema, "decision_date", :fast_stored)

    # Parties and entities
    {:ok, schema} = Schema.add_text_field(schema, "plaintiff", :text_stored)
    {:ok, schema} = Schema.add_text_field(schema, "defendant", :text_stored)
    {:ok, schema} = Schema.add_text_field(schema, "judge", :text_stored)
    {:ok, schema} = Schema.add_text_field(schema, "attorney_firm", :text_stored)

    # Document metadata
    {:ok, schema} = Schema.add_text_field(schema, "language", :fast)
    {:ok, schema} = Schema.add_u64_field(schema, "page_count", :fast_stored)
    {:ok, schema} = Schema.add_f64_field(schema, "confidence_score", :fast)  # OCR confidence
    {:ok, schema} = Schema.add_text_field(schema, "file_format", :fast)

    # Access control and security
    {:ok, schema} = Schema.add_facet_field(schema, "security_classification", :facet)
    {:ok, schema} = Schema.add_json_field(schema, "access_permissions", :stored)
    {:ok, schema} = Schema.add_text_field(schema, "owner", :fast)

    # Versioning and workflow
    {:ok, schema} = Schema.add_u64_field(schema, "version", :fast_stored)
    {:ok, schema} = Schema.add_text_field(schema, "status", :fast)  # draft, reviewed, approved, archived
    {:ok, schema} = Schema.add_text_field(schema, "workflow_stage", :fast)

    # Citations and references
    {:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "cited_cases", :text, "whitespace")
    {:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "cited_statutes", :text, "whitespace")
    {:ok, schema} = Schema.add_u64_field(schema, "citation_count", :fast)

    # Timestamps
    {:ok, schema} = Schema.add_date_field(schema, "created_at", :fast_stored)
    {:ok, schema} = Schema.add_date_field(schema, "updated_at", :fast_stored)
    {:ok, schema} = Schema.add_date_field(schema, "last_accessed", :fast)

    {:ok, schema}
  end
end
```

### Social Media Analytics

This example shows a schema for social media post analysis:

```elixir
defmodule SocialMediaSchema do
  alias TantivyEx.Schema

  def create_social_post_schema do
    {:ok, schema} = Schema.new()

    # Post identification
    {:ok, schema} = Schema.add_text_field(schema, "id", :stored)
    {:ok, schema} = Schema.add_text_field(schema, "platform_id", :text_stored)  # Original platform ID
    {:ok, schema} = Schema.add_text_field(schema, "platform", :fast)  # twitter, facebook, instagram

    # Content fields
    {:ok, schema} = Schema.add_text_field(schema, "content", :text_stored)  # Need to display
    {:ok, schema} = Schema.add_text_field(schema, "title", :text_stored)
    {:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "hashtags", :text, "whitespace")
    {:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "mentions", :text, "whitespace")

    # Author information
    {:ok, schema} = Schema.add_text_field(schema, "author_username", :fast_stored)
    {:ok, schema} = Schema.add_text_field(schema, "author_display_name", :text_stored)
    {:ok, schema} = Schema.add_u64_field(schema, "author_follower_count", :fast)
    {:ok, schema} = Schema.add_text_field(schema, "author_verified", :fast)  # true/false

    # Engagement metrics
    {:ok, schema} = Schema.add_u64_field(schema, "like_count", :fast_stored)
    {:ok, schema} = Schema.add_u64_field(schema, "share_count", :fast_stored)
    {:ok, schema} = Schema.add_u64_field(schema, "comment_count", :fast_stored)
    {:ok, schema} = Schema.add_u64_field(schema, "view_count", :fast)
    {:ok, schema} = Schema.add_f64_field(schema, "engagement_rate", :fast)

    # Sentiment and analysis
    {:ok, schema} = Schema.add_text_field(schema, "sentiment", :fast)  # positive, negative, neutral
    {:ok, schema} = Schema.add_f64_field(schema, "sentiment_score", :fast_stored)  # -1.0 to 1.0
    {:ok, schema} = Schema.add_f64_field(schema, "toxicity_score", :fast)
    {:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "topics", :text, "whitespace")

    # Geographic and temporal data
    {:ok, schema} = Schema.add_text_field(schema, "country", :fast)
    {:ok, schema} = Schema.add_text_field(schema, "city", :fast)
    {:ok, schema} = Schema.add_f64_field(schema, "latitude", :fast)
    {:ok, schema} = Schema.add_f64_field(schema, "longitude", :fast)
    {:ok, schema} = Schema.add_date_field(schema, "posted_at", :fast_stored)
    {:ok, schema} = Schema.add_u64_field(schema, "hour_of_day", :fast)  # 0-23
    {:ok, schema} = Schema.add_u64_field(schema, "day_of_week", :fast)  # 1-7

    # Content classification
    {:ok, schema} = Schema.add_facet_field(schema, "content_type", :facet)  # /text, /image, /video
    {:ok, schema} = Schema.add_text_field(schema, "language", :fast)
    {:ok, schema} = Schema.add_text_field(schema, "adult_content", :fast)  # safe, questionable, explicit

    # Campaign and tracking
    {:ok, schema} = Schema.add_text_field(schema, "campaign_id", :fast)
    {:ok, schema} = Schema.add_text_field_with_tokenizer(schema, "tracking_codes", :text, "whitespace")
    {:ok, schema} = Schema.add_text_field(schema, "source", :fast)  # organic, paid, influencer

    # Media attachments
    {:ok, schema} = Schema.add_u64_field(schema, "media_count", :fast)
    {:ok, schema} = Schema.add_json_field(schema, "media_metadata", :stored)

    {:ok, schema}
  end

  # Example query patterns for social media analytics
  def trending_hashtags_query(time_range_start, time_range_end) do
    "posted_at:[#{time_range_start} TO #{time_range_end}] AND engagement_rate:[0.05 TO *]"
  end

  def viral_content_query(min_shares \\ 100) do
    "share_count:[#{min_shares} TO *] AND sentiment:positive"
  end

  def brand_mention_query(brand_name) do
    "(content:\"#{brand_name}\" OR mentions:\"@#{brand_name}\")"
  end
end
```

These real-world examples demonstrate how to design schemas for different domains, showing the thought process behind field selection, option choices, and query patterns. Each schema is optimized for its specific use case while maintaining good performance characteristics.

---

## Summary

Effective schema design is crucial for search performance and functionality. Remember these key principles:

1. **Choose appropriate field types** for your data
2. **Select field options** based on query requirements
3. **Balance storage and performance** needs
4. **Plan for future requirements** when possible
5. **Validate your schema** before production use

Take time to understand your search requirements and data characteristics before designing your schema. A well-designed schema will serve as the foundation for a fast, reliable search experience.
