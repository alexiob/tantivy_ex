# Document Guide

This comprehensive guide covers document operations in TantivyEx, including creation, validation, indexing, and best practices for working with documents.

## Table of Contents

- [Document Fundamentals](#document-fundamentals)
- [Document Creation](#document-creation)
- [Field Types and Values](#field-types-and-values)
- [Document Validation](#document-validation)
- [Indexing Operations](#indexing-operations)
- [Batch Processing](#batch-processing)
- [Advanced Topics](#advanced-topics)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Document Fundamentals

### What is a Document?

In TantivyEx, a document is a collection of fields and their values that represents a single unit of data in your search index. Documents are typically represented as Elixir maps where keys are field names and values are the field data.

```elixir
# Basic document structure
document = %{
  "title" => "Introduction to Elixir",
  "content" => "Elixir is a dynamic, functional language designed for building maintainable applications.",
  "author" => "José Valim",
  "published_at" => "2011-07-11T00:00:00Z",
  "tags" => "/programming/functional/elixir",
  "price" => 49.99,
  "available" => true
}
```

### Document Schema Relationship

Documents must conform to the schema you've defined for your index. The schema determines:

- Which fields are available
- What types of data each field can contain
- How fields are indexed and stored
- Whether fields support faceting, full-text search, or fast filtering

```elixir
# Define schema first
{:ok, schema} = TantivyEx.Schema.new()
  |> TantivyEx.Schema.add_text_field("title", stored: true, indexed: true)
  |> TantivyEx.Schema.add_text_field("content", stored: true, indexed: true)
  |> TantivyEx.Schema.add_u64_field("price", stored: true, fast: true)
  |> TantivyEx.Schema.build()

# Then create documents that match the schema
document = %{
  "title" => "Sample Document",
  "content" => "This document matches our schema perfectly.",
  "price" => 1999  # Note: price as integer (u64)
}
```

## Document Creation

### Basic Document Creation

Create documents as simple Elixir maps:

```elixir
# Text document for a blog post
blog_post = %{
  "title" => "Getting Started with TantivyEx",
  "content" => "TantivyEx brings powerful full-text search capabilities to Elixir applications...",
  "author" => "Your Name",
  "published_at" => "2024-01-15T10:30:00Z",
  "category" => "/blog/tutorials/elixir"
}

# Product document for e-commerce
product = %{
  "name" => "Wireless Headphones",
  "description" => "High-quality wireless headphones with noise cancellation",
  "price" => 19999,  # Price in cents
  "brand" => "AudioTech",
  "category" => "/electronics/audio/headphones",
  "in_stock" => true,
  "release_date" => "2024-01-01T00:00:00Z"
}

# User document for search
user = %{
  "username" => "john_doe",
  "email" => "john@example.com",
  "full_name" => "John Doe",
  "bio" => "Software developer with 10 years of experience",
  "location" => "San Francisco, CA",
  "joined_at" => "2023-06-15T14:22:00Z",
  "is_verified" => true
}
```

### Dynamic Document Creation

Build documents programmatically:

```elixir
def create_article_document(article, author) do
  %{
    "title" => article.title,
    "content" => article.body,
    "author" => author.name,
    "author_id" => author.id,
    "published_at" => DateTime.to_iso8601(article.published_at),
    "word_count" => String.split(article.body) |> length(),
    "category" => "/articles/#{article.category}",
    "tags" => Enum.join(article.tags, " "),
    "featured" => article.featured?,
    "views" => article.view_count
  }
end

# Usage
document = create_article_document(article, author)
```

## Field Types and Values

### Text Fields

Text fields support full-text search and tokenization:

```elixir
# Simple text
%{"title" => "Machine Learning Basics"}

# Long text content
%{
  "content" => """
  Machine learning is a method of data analysis that automates analytical
  model building. It is a branch of artificial intelligence based on the
  idea that systems can learn from data, identify patterns and make
  decisions with minimal human intervention.
  """
}

# Multiple language support
%{
  "title_en" => "Hello World",
  "title_es" => "Hola Mundo",
  "title_fr" => "Bonjour le Monde"
}
```

### Numeric Fields

Numeric fields support range queries and sorting:

```elixir
# Unsigned 64-bit integers (u64)
%{
  "price" => 2999,        # Price in cents
  "views" => 1024,        # View count
  "likes" => 42           # Social engagement
}

# Signed 64-bit integers (i64)
%{
  "temperature" => -15,   # Can be negative
  "elevation" => 2847,    # Altitude in meters
  "score_diff" => -5      # Score difference
}

# Floating-point numbers (f64)
%{
  "rating" => 4.7,        # Star rating
  "longitude" => -122.4194, # GPS coordinates
  "latitude" => 37.7749,
  "price_usd" => 29.99    # Decimal price
}
```

### Boolean Fields

Boolean fields for true/false values:

```elixir
%{
  "published" => true,
  "featured" => false,
  "in_stock" => true,
  "on_sale" => false,
  "verified" => true
}
```

### Date Fields

Date and time values (stored as Unix timestamps):

```elixir
# ISO 8601 string format (recommended)
%{
  "created_at" => "2024-01-15T10:30:00Z",
  "updated_at" => "2024-01-15T14:45:30.123Z",
  "published_at" => "2024-01-15T09:00:00-08:00"  # With timezone
}

# Unix timestamp (integer seconds)
%{
  "created_at" => 1705317000,  # Equivalent to above
  "expires_at" => 1705403400   # 24 hours later
}

# Current time helper
%{
  "indexed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
}
```

### Facet Fields

Hierarchical facets for categorization and filtering:

```elixir
%{
  # Product categories
  "category" => "/electronics/computers/laptops",

  # Geographic hierarchy
  "location" => "/usa/california/san_francisco",

  # Content taxonomy
  "topic" => "/programming/languages/elixir/otp",

  # Multi-level tags
  "tags" => "/blog/technical/tutorial"
}

# Multiple facets
%{
  "primary_category" => "/books/fiction/mystery",
  "secondary_category" => "/books/bestsellers",
  "age_rating" => "/ratings/mature"
}
```

### Binary Data (Bytes)

Store binary data as base64-encoded strings:

```elixir
# Base64-encoded data
%{
  "thumbnail" => "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
  "signature" => "SGVsbG8gV29ybGQ=",  # "Hello World" in base64
  "metadata" => Base.encode64(Jason.encode!(%{version: "1.0", type: "image"}))
}

# Binary data from files
%{
  "file_content" => File.read!("document.pdf") |> Base.encode64(),
  "image_data" => File.read!("image.png") |> Base.encode64()
}
```

### JSON Objects

Complex nested data structures:

```elixir
%{
  "metadata" => %{
    "version" => "2.1",
    "format" => "json",
    "compression" => "gzip",
    "size_bytes" => 1024
  },

  "settings" => %{
    "notifications" => %{
      "email" => true,
      "push" => false,
      "sms" => true
    },
    "privacy" => %{
      "public_profile" => false,
      "show_email" => false
    }
  }
}
```

### IP Addresses

IPv4 and IPv6 addresses:

```elixir
%{
  "client_ip" => "192.168.1.1",           # IPv4
  "server_ip" => "2001:db8::1",           # IPv6
  "proxy_ip" => "10.0.0.1",               # Private IPv4
  "cdn_ip" => "2606:4700:3034::ac43:c427" # IPv6 CDN
}
```

## Document Validation

### Schema-Based Validation

Validate documents against your schema before indexing:

```elixir
# Define your schema
{:ok, schema} = TantivyEx.Schema.new()
  |> TantivyEx.Schema.add_text_field("title", stored: true)
  |> TantivyEx.Schema.add_u64_field("price", stored: true)
  |> TantivyEx.Schema.add_bool_field("available", stored: true)
  |> TantivyEx.Schema.build()

# Create a document
document = %{
  "title" => "Product Name",
  "price" => 1999,
  "available" => true
}

# Validate the document
case TantivyEx.Document.validate(document, schema) do
  {:ok, validated_doc} ->
    IO.puts("Document is valid!")
    # Proceed with indexing

  {:error, reason} ->
    IO.puts("Validation failed: #{reason}")
    # Handle validation error
end
```

### Type Conversion and Validation

TantivyEx automatically converts compatible types:

```elixir
# These values will be automatically converted:
document = %{
  "price" => "1999",           # String -> u64
  "rating" => "4.5",           # String -> f64
  "available" => "true",       # String -> boolean
  "count" => 42.0              # f64 -> u64 (if whole number)
}

# Validation with helpful error messages
{:error, "Field 'price': Expected numeric value"} =
  TantivyEx.Document.validate(%{"price" => "not_a_number"}, schema)
```

### Custom Validation Functions

Create custom validation logic:

```elixir
defmodule MyApp.DocumentValidator do
  def validate_product(document) do
    with {:ok, doc} <- validate_required_fields(document),
         {:ok, doc} <- validate_price_range(doc),
         {:ok, doc} <- validate_category_format(doc) do
      {:ok, doc}
    end
  end

  defp validate_required_fields(doc) do
    required = ["title", "price", "category"]
    missing = required -- Map.keys(doc)

    case missing do
      [] -> {:ok, doc}
      fields -> {:error, "Missing required fields: #{Enum.join(fields, ", ")}"}
    end
  end

  defp validate_price_range(doc) do
    price = Map.get(doc, "price", 0)

    if price > 0 and price < 1_000_000 do
      {:ok, doc}
    else
      {:error, "Price must be between 1 and 999,999"}
    end
  end

  defp validate_category_format(doc) do
    category = Map.get(doc, "category", "")

    if String.starts_with?(category, "/") do
      {:ok, doc}
    else
      {:error, "Category must start with '/'"}
    end
  end
end
```

## Indexing Operations

### Single Document Indexing

Add individual documents to the index:

```elixir
# Open an index and get a writer
{:ok, index} = TantivyEx.Index.open("path/to/index")
{:ok, writer} = TantivyEx.IndexWriter.new(index)

# Create and validate document
document = %{
  "title" => "New Article",
  "content" => "Article content here...",
  "published_at" => DateTime.utc_now() |> DateTime.to_iso8601()
}

# Add document to index
case TantivyEx.IndexWriter.add_document(writer, document) do
  :ok ->
    IO.puts("Document indexed successfully")

  {:error, reason} ->
    IO.puts("Failed to index document: #{reason}")
end

# Commit changes to make them searchable
:ok = TantivyEx.IndexWriter.commit(writer)
```

### Schema-Aware Indexing

Use schema information for better type handling:

```elixir
# Add document with schema validation
case TantivyEx.IndexWriter.add_document(writer, document) do
  :ok ->
    IO.puts("Document added with schema validation")

  {:error, reason} ->
    IO.puts("Schema validation failed: #{reason}")
end
```

### Handling Indexing Errors

Robust error handling for production use:

```elixir
def safely_index_document(writer, document, schema) do
  try do
    case TantivyEx.Document.validate(document, schema) do
      {:ok, validated_doc} ->
        case TantivyEx.Document.add_with_schema(writer, validated_doc, schema) do
          :ok ->
            {:ok, :indexed}
          {:error, reason} ->
            {:error, {:indexing_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:validation_failed, reason}}
    end
  rescue
    exception ->
      {:error, {:exception, Exception.message(exception)}}
  end
end
```

## Batch Processing

### Batch Document Addition

Process multiple documents efficiently:

```elixir
# Prepare batch of documents
documents = [
  %{"title" => "Doc 1", "content" => "Content 1"},
  %{"title" => "Doc 2", "content" => "Content 2"},
  %{"title" => "Doc 3", "content" => "Content 3"}
]

# Batch add with comprehensive results
case TantivyEx.Document.add_batch(writer, documents, schema) do
  {:ok, results} ->
    IO.puts("Batch completed: #{results}")
    # Results format: {"successful": 3, "errors": 0}

  {:error, errors} ->
    IO.puts("Batch had errors: #{inspect(errors)}")
    # Errors format: [{index, error_message}, ...]
end
```

### Processing Large Datasets

Handle large document collections efficiently:

```elixir
defmodule MyApp.BulkIndexer do
  @batch_size 1000

  def index_all_documents(writer, documents, schema) do
    documents
    |> Stream.chunk_every(@batch_size)
    |> Stream.with_index()
    |> Enum.reduce({0, []}, fn {batch, batch_num}, {total_success, all_errors} ->
      IO.puts("Processing batch #{batch_num + 1}")

      case TantivyEx.Document.add_batch(writer, batch, schema) do
        {:ok, result} ->
          success_count = parse_success_count(result)
          {total_success + success_count, all_errors}

        {:error, errors} ->
          {total_success, all_errors ++ errors}
      end
    end)
  end

  defp parse_success_count(result_json) do
    case Jason.decode(result_json) do
      {:ok, %{"successful" => count}} -> count
      _ -> 0
    end
  end
end

# Usage
{success_count, errors} = MyApp.BulkIndexer.index_all_documents(writer, documents, schema)
IO.puts("Indexed #{success_count} documents with #{length(errors)} errors")
```

### Memory-Efficient Streaming

Stream large datasets without loading everything into memory:

```elixir
defmodule MyApp.StreamingIndexer do
  def index_from_stream(writer, document_stream, schema) do
    document_stream
    |> Stream.map(&validate_and_prepare/1)
    |> Stream.filter(&match?({:ok, _}, &1))
    |> Stream.map(fn {:ok, doc} -> doc end)
    |> Stream.chunk_every(500)
    |> Enum.each(fn batch ->
      case TantivyEx.Document.add_batch(writer, batch, schema) do
        {:ok, _} -> :ok
        {:error, errors} ->
          Logger.error("Batch indexing errors: #{inspect(errors)}")
      end
    end)
  end

  defp validate_and_prepare(raw_document) do
    # Custom preparation logic
    case prepare_document(raw_document) do
      {:ok, doc} -> {:ok, doc}
      {:error, reason} ->
        Logger.warning("Document preparation failed: #{reason}")
        {:error, reason}
    end
  end
end
```

## Advanced Topics

### Document Updates

TantivyEx doesn't support in-place updates, but you can rebuild indices:

```elixir
defmodule MyApp.DocumentUpdater do
  def update_document(old_index_path, new_index_path, doc_id, updates, schema) do
    # Create new index
    {:ok, new_index} = TantivyEx.Index.create(new_index_path, schema)
    {:ok, writer} = TantivyEx.IndexWriter.new(new_index)

    # Copy all documents except the one being updated
    {:ok, searcher} = TantivyEx.Searcher.new(old_index_path)

    # This is a simplified approach - in practice you'd want to
    # stream through all documents more efficiently
    documents = get_all_documents(searcher)

    updated_documents = documents
    |> Enum.map(fn doc ->
      if doc["id"] == doc_id do
        Map.merge(doc, updates)
      else
        doc
      end
    end)

    # Index all documents to new index
    case TantivyEx.IndexWriter.add_document(writer, updated_documents) do
      :ok ->
        :ok = TantivyEx.IndexWriter.commit(writer)
        {:ok, new_index}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

### Document Deletion

Implement document deletion through index rebuilding:

```elixir
def delete_documents(index_path, new_index_path, doc_ids, schema) do
  delete_set = MapSet.new(doc_ids)

  {:ok, new_index} = TantivyEx.Index.create(new_index_path, schema)
  {:ok, writer} = TantivyEx.IndexWriter.new(new_index)

  # Copy all documents except those being deleted
  documents = get_all_documents_from_index(index_path)

  filtered_documents = Enum.reject(documents, fn doc ->
    MapSet.member?(delete_set, doc["id"])
  end)

  case TantivyEx.Document.add_batch(writer, filtered_documents, schema) do
    {:ok, _} ->
      :ok = TantivyEx.IndexWriter.commit(writer)
      {:ok, new_index}

    {:error, reason} ->
      {:error, reason}
  end
end
```

### Complex Document Structures

Handle nested data and complex transformations:

```elixir
defmodule MyApp.ComplexDocuments do
  def transform_product_for_search(product) do
    %{
      "id" => product.id,
      "name" => product.name,
      "description" => product.description,

      # Flatten nested attributes
      "brand" => product.brand.name,
      "brand_id" => product.brand.id,

      # Create searchable text from multiple fields
      "searchable_text" => build_searchable_text(product),

      # Price information
      "price_cents" => product.price_cents,
      "price_usd" => product.price_cents / 100.0,

      # Category hierarchy
      "category" => build_category_path(product.categories),

      # Inventory data
      "in_stock" => product.inventory.quantity > 0,
      "quantity" => product.inventory.quantity,

      # Dates
      "created_at" => DateTime.to_iso8601(product.inserted_at),
      "updated_at" => DateTime.to_iso8601(product.updated_at),

      # Features and tags
      "features" => Enum.join(product.features, " "),
      "tags" => build_tag_facets(product.tags)
    }
  end

  defp build_searchable_text(product) do
    [
      product.name,
      product.description,
      product.brand.name,
      Enum.join(product.features, " "),
      Enum.map(product.tags, & &1.name) |> Enum.join(" ")
    ]
    |> Enum.join(" ")
    |> String.downcase()
  end

  defp build_category_path(categories) do
    categories
    |> Enum.map(& &1.slug)
    |> Enum.join("/")
    |> then(&"/#{&1}")
  end

  defp build_tag_facets(tags) do
    tags
    |> Enum.map(& &1.category)
    |> Enum.uniq()
    |> Enum.join("/")
    |> then(&"/tags/#{&1}")
  end
end
```

## Best Practices

### Document Design Principles

1. **Keep Fields Focused**: Each field should have a single, clear purpose
2. **Use Appropriate Types**: Choose the right field type for your data
3. **Design for Queries**: Structure documents to support your search patterns
4. **Normalize When Appropriate**: Consider denormalizing data for search performance

```elixir
# Good: Clear field purposes
%{
  "title" => "Document title",
  "content" => "Main document content",
  "author" => "Author name",
  "published_at" => "2024-01-15T10:30:00Z",
  "word_count" => 1500,
  "category" => "/articles/technical"
}

# Avoid: Mixed purposes in single fields
%{
  "metadata" => "Title: Document | Author: John | Date: 2024-01-15"  # Hard to search
}
```

### Performance Optimization

1. **Batch Operations**: Use batch processing for multiple documents
2. **Schema Design**: Design schema fields to match query patterns
3. **Field Options**: Use appropriate indexing options (stored, fast, indexed)
4. **Memory Management**: Process large datasets in chunks

```elixir
# Efficient batch processing
def index_efficiently(writer, large_dataset, schema) do
  large_dataset
  |> Stream.chunk_every(1000)  # Process in batches
  |> Stream.map(fn batch ->
    # Pre-validate batch
    validated_batch = Enum.filter(batch, &valid_document?/1)
    TantivyEx.Document.add_batch(writer, validated_batch, schema)
  end)
  |> Stream.run()  # Execute the stream
end
```

### Error Handling

1. **Validate Early**: Check documents before attempting to index
2. **Graceful Degradation**: Handle partial failures in batch operations
3. **Logging**: Log validation and indexing errors for debugging
4. **Recovery**: Implement retry logic for transient failures

```elixir
defmodule MyApp.SafeIndexer do
  require Logger

  def safe_index(writer, document, schema, retries \\ 3) do
    case TantivyEx.Document.validate(document, schema) do
      {:ok, validated_doc} ->
        attempt_index(writer, validated_doc, schema, retries)

      {:error, reason} ->
        Logger.error("Document validation failed: #{reason}")
        {:error, {:validation, reason}}
    end
  end

  defp attempt_index(writer, document, schema, retries) when retries > 0 do
    case TantivyEx.Document.add_with_schema(writer, document, schema) do
      :ok ->
        {:ok, :indexed}

      {:error, reason} when retries > 1 ->
        Logger.warning("Indexing failed, retrying: #{reason}")
        :timer.sleep(100)  # Brief delay
        attempt_index(writer, document, schema, retries - 1)

      {:error, reason} ->
        Logger.error("Indexing failed after retries: #{reason}")
        {:error, {:indexing, reason}}
    end
  end
end
```

### Data Consistency

1. **Atomic Operations**: Ensure related documents are indexed together
2. **Version Control**: Include version information in documents
3. **Validation**: Implement comprehensive validation rules
4. **Backup Strategy**: Regular index backups before major updates

```elixir
# Version-aware documents
%{
  "id" => "doc_123",
  "version" => 3,
  "title" => "Updated Document",
  "last_modified" => DateTime.utc_now() |> DateTime.to_iso8601(),
  "checksum" => :crypto.hash(:sha256, content) |> Base.encode16()
}
```

## Troubleshooting

### Common Issues

#### Type Mismatch Errors

```elixir
# Problem: Wrong data type
document = %{"price" => "not_a_number"}

# Solution: Proper type conversion
document = %{"price" => String.to_integer(price_string)}
```

#### Missing Required Fields

```elixir
# Problem: Document missing schema fields
document = %{"title" => "Test"}  # Missing other required fields

# Solution: Complete document validation
defp ensure_required_fields(document, required_fields) do
  missing = required_fields -- Map.keys(document)
  if missing == [], do: {:ok, document}, else: {:error, "Missing: #{inspect(missing)}"}
end
```

#### Large Document Performance

```elixir
# Problem: Very large documents causing memory issues
huge_document = %{"content" => very_large_text}

# Solution: Content chunking or field splitting
def split_large_content(content, max_size \\ 10_000) do
  if String.length(content) > max_size do
    content
    |> String.graphemes()
    |> Enum.chunk_every(max_size)
    |> Enum.map(&Enum.join/1)
  else
    [content]
  end
end
```

#### Batch Processing Failures

```elixir
# Problem: Entire batch fails due to one bad document
documents = [good_doc1, bad_doc, good_doc2]

# Solution: Filter and process valid documents
def process_with_filtering(writer, documents, schema) do
  {valid_docs, invalid_docs} =
    Enum.split_with(documents, &valid_document?(&1, schema))

  result = TantivyEx.Document.add_batch(writer, valid_docs, schema)

  unless Enum.empty?(invalid_docs) do
    Logger.warning("Skipped #{length(invalid_docs)} invalid documents")
  end

  result
end
```

### Debugging Tips

1. **Enable Logging**: Use Logger to track document processing
2. **Validate Incrementally**: Test schema and documents separately
3. **Check Field Types**: Verify field type definitions match your data
4. **Monitor Memory**: Watch memory usage during large batch operations
5. **Test with Small Batches**: Start with small batches to identify issues

```elixir
# Debug document structure
def debug_document(document, schema) do
  IO.puts("Document keys: #{inspect(Map.keys(document))}")
  IO.puts("Schema fields: #{inspect(TantivyEx.Schema.field_names(schema))}")

  # Check each field type
  Enum.each(document, fn {field, value} ->
    IO.puts("#{field}: #{inspect(value)} (#{inspect(value.__struct__ || typeof(value))})")
  end)
end
```

This comprehensive document guide provides everything you need to work effectively with documents in TantivyEx, from basic operations to advanced patterns and troubleshooting.
