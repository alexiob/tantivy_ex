# Core Concepts

Understanding TantivyEx's core concepts will help you build better search applications and make informed design decisions.

## What is TantivyEx?

TantivyEx is an Elixir wrapper around [Tantivy](https://github.com/quickwit-oss/tantivy), a full-text search engine library written in Rust. It provides:

- **High Performance**: Leverages Rust's memory safety and speed
- **Full-Text Search**: Advanced text processing and ranking
- **Flexible Schema**: Support for various field types and options
- **Real-Time Updates**: Add, update, and delete documents efficiently
- **Query Language**: Rich query syntax for complex searches

## Key Components

### 1. Index

An **Index** is a data structure that stores your documents in a way that enables fast search operations. Think of it as a specialized database optimized for text search.

```elixir
# Create an index in memory (for testing)
{:ok, index} = Index.create_in_ram(schema)

# Create a persistent index (for production)
{:ok, index} = Index.create_in_dir("/path/to/index", schema)

# Open an existing index
{:ok, index} = Index.open("/path/to/index")

# Open existing or create new index (recommended)
{:ok, index} = Index.open_or_create("/path/to/index", schema)
```

**Index Types:**

- **In-Memory**: Fast, temporary, lost on restart
- **Persistent**: Stored on disk, survives restarts
- **Distributed**: Multiple shards (advanced topic)

**Index Management Functions:**

- `create_in_dir/2`: Creates new index, fails if exists
- `create_in_ram/1`: Creates temporary in-memory index
- `open/1`: Opens existing index, fails if doesn't exist
- `open_or_create/2`: Opens existing or creates new (production recommended)

### 2. Schema

A **Schema** defines the structure of your documents - what fields they have and how those fields should be processed and stored.

```elixir
schema = Schema.new()
schema = Schema.add_text_field(schema, "title", :text_stored)
schema = Schema.add_u64_field(schema, "timestamp", :fast_stored)
```

**Schema Design Principles:**

- Define all fields upfront
- Choose appropriate field types and options
- Consider storage vs. performance trade-offs
- Plan for future requirements

### 3. Documents

**Documents** are the actual data you want to search. They must conform to your schema.

```elixir
document = %{
  "title" => "Introduction to Elixir",
  "timestamp" => 1640995200
}

{:ok, writer} = TantivyEx.IndexWriter.new(index)
:ok = TantivyEx.IndexWriter.add_document(writer, document)
```

**Document Characteristics:**

- Must match the schema structure
- Can contain only defined fields
- Support various data types
- Immutable once added (update = delete + add)

### 4. Fields

**Fields** are the individual pieces of data in your documents. Different field types are optimized for different use cases:

#### Text Fields

```elixir
# For full-text search
schema = Schema.add_text_field(schema, "content", :text)

# For exact matches and storage
schema = Schema.add_text_field(schema, "title", :text_stored)
```

#### Numeric Fields

```elixir
# For integers
schema = Schema.add_u64_field(schema, "timestamp", :fast_stored)
schema = Schema.add_i64_field(schema, "score", :fast)

# For floating point
schema = Schema.add_f64_field(schema, "price", :fast_stored)
```

#### Facet Fields

```elixir
# For hierarchical filtering
schema = Schema.add_facet_field(schema, "category", :facet)
```

#### Binary Fields

```elixir
# For storing raw data
schema = Schema.add_bytes_field(schema, "thumbnail", :stored)
```

### 5. Queries

**Queries** are how you search your index. TantivyEx supports a rich query language:

```elixir
# Simple term search
{:ok, searcher} = TantivyEx.Searcher.new(index)
TantivyEx.Searcher.search(searcher, "elixir", 10)

# Boolean queries
TantivyEx.Searcher.search(searcher, "elixir AND phoenix", 10)

# Range queries
TantivyEx.Searcher.search(searcher, "price:[10.0 TO 100.0]", 10)

# Field-specific search
TantivyEx.Searcher.search(searcher, "title:elixir", 10)
```

## Data Flow

Understanding the data flow helps you design better search applications:

1. **Schema Definition** → Define your document structure
2. **Index Creation** → Create storage for your documents
3. **Document Addition** → Add your data to the index
4. **Commit** → Make changes searchable
5. **Query Execution** → Search and retrieve results

```elixir
# 1. Define schema
{:ok, schema} = Schema.new() |> Schema.add_text_field("title", :text_stored)

# 2. Create index
{:ok, index} = Index.create_in_ram(schema)

# 3. Add documents
{:ok, writer} = TantivyEx.IndexWriter.new(index)
:ok = TantivyEx.IndexWriter.add_document(writer, %{"title" => "Hello World"})

# 4. Commit (make searchable)
:ok = TantivyEx.IndexWriter.commit(writer)

# 5. Search
{:ok, searcher} = TantivyEx.Searcher.new(index)
{:ok, results} = TantivyEx.Searcher.search(searcher, "hello", 10)
```

## Field Options Deep Dive

Understanding field options is crucial for performance and functionality:

### Storage Options

- **`:stored`** - Field value is stored and can be retrieved
- **`:fast`** - Field is indexed for fast filtering and sorting
- **`:indexed`** - Field is searchable (default for text fields)

### Combined Options

- **`:text_stored`** - Text field that's both searchable and stored
- **`:fast_stored`** - Numeric field that's fast-accessible and stored
- **`:facet`** - Facet field for hierarchical filtering

### Choosing Options

```elixir
# For full-text search with retrieval
Schema.add_text_field(schema, "content", :text_stored)

# For filtering without retrieval
Schema.add_u64_field(schema, "timestamp", :fast)

# For display-only fields
Schema.add_text_field(schema, "author", :stored)

# For hierarchical navigation
Schema.add_facet_field(schema, "category", :facet)
```

## Memory and Performance Considerations

### Index Structure

- **Segments**: Immutable chunks of data
- **Merging**: Combines segments for efficiency
- **Commits**: Make changes visible to searchers

### Memory Usage

- **In-memory indexes**: Fast but limited by RAM
- **Disk indexes**: Scalable but slower access
- **Caching**: Frequently accessed data in memory

### Performance Tips

- Use appropriate field types
- Minimize stored fields for large datasets
- Batch document operations
- Optimize commit frequency

## Error Handling Patterns

TantivyEx follows Elixir conventions with `{:ok, result}` and `{:error, reason}` tuples:

```elixir
case TantivyEx.Searcher.search(searcher, query, limit) do
  {:ok, results} ->
    process_results(results)

  {:error, :invalid_query} ->
    {:error, "Invalid search query format"}

  {:error, reason} ->
    Logger.error("Search failed: #{inspect(reason)}")
    {:error, "Search temporarily unavailable"}
end
```

## Glossary

### A-C

**Analyzer**
: A component that processes text fields during indexing. It typically includes tokenization, stemming, and filtering. Analyzers determine how text is broken down and normalized for search.

**Commit**
: The operation that makes indexed documents visible to searchers. Until a commit occurs, newly added documents won't appear in search results. Commits also persist changes to disk for persistent indexes.

**Collector**
: A component that gathers search results during query execution. Different collectors can sort results, apply scoring, or collect specific types of data (e.g., facet counts, top documents).

### D-F

**Document**
: A single record in your search index, represented as a collection of fields. Documents must conform to the schema and are the basic unit of indexing and retrieval.

**Facet**
: A hierarchical field type used for categorical navigation and filtering. Facets allow users to drill down through categories (e.g., "Electronics/Computers/Laptops") and get counts for each category level.

```elixir
# Example facet structure
"/Electronics/Computers/Laptops"
"/Electronics/Phones/Smartphones"
"/Books/Fiction/Science Fiction"
```

**Field**
: A named attribute of a document (e.g., "title", "content", "price"). Each field has a specific type and configuration that determines how it's indexed and stored.

**Field Options**
: Configuration flags that control how fields are processed:

- `:stored` - Field value is retrievable from search results
- `:indexed` - Field is searchable (default for text fields)
- `:fast` - Field supports fast filtering, sorting, and aggregation

### G-I

**Index**
: The core data structure that stores documents in an optimized format for fast search operations. Can be in-memory (temporary) or persistent (disk-based).

**Index Writer**
: The component responsible for adding, updating, and deleting documents in an index. Only one writer can be active per index at a time to ensure consistency.

**Inverted Index**
: The underlying data structure that maps terms to the documents containing them. This enables fast text search by looking up terms directly rather than scanning all documents.

### J-M

**JSON Field**
: A special field type that can store and search structured JSON data. Allows dynamic schemas and complex nested data structures.

**Merge Policy**
: Rules that determine when and how index segments are combined. Affects indexing performance and search speed by controlling the number and size of segments.

### N-Q

**Query**
: A search expression that specifies what documents to find. Can range from simple term queries to complex boolean expressions with filters and scoring modifications.

**Query Parser**
: Component that converts human-readable query strings into internal query objects. Supports various syntaxes like boolean operators, field-specific searches, and range queries.

### R-S

**Schema**
: The blueprint that defines the structure of documents in an index. Specifies all possible fields, their types, and how they should be processed. Must be defined before creating an index.

**Searcher**
: A read-only component that executes queries against an index. Multiple searchers can operate simultaneously, and they provide a consistent view of the index at a point in time.

**Segment**
: An immutable chunk of the index containing a subset of documents. New documents are added to new segments, and segments are periodically merged for efficiency.

**Snippet**
: A highlighted excerpt from a document that shows where query terms appear in context. Used to provide search result previews with relevant portions emphasized.

**Stemming**
: The process of reducing words to their root form (e.g., "running" → "run"). Improves search recall by matching different word forms.

### T-Z

**Term**
: A single unit of text after tokenization and processing. For example, "machine learning" might become two terms: "machine" and "learn" (after stemming).

**Term Dictionary**
: An internal data structure that efficiently stores all unique terms in the index along with their statistics and pointers to document lists.

**Tokenizer**
: Component that breaks text into individual terms. Different tokenizers handle different languages and text types (e.g., splitting on whitespace, handling punctuation, processing URLs).

```elixir
# Example tokenization
"Hello, world!" → ["hello", "world"]
"user@example.com" → ["user", "example", "com"] # with email tokenizer
```

**TF-IDF (Term Frequency-Inverse Document Frequency)**
: A scoring algorithm that ranks documents based on how frequently terms appear in the document versus how common they are across the entire index. More unique terms get higher scores.

**Writer**
: See Index Writer.

## Usage Examples by Term

### Working with Facets

```elixir
# Define facet field
{:ok, schema} = Schema.add_facet_field(schema, "category", :facet)

# Add document with facet
document = %{"category" => "/Electronics/Computers/Laptops"}
TantivyEx.IndexWriter.add_document(writer, document)

# Query with facet filter
{:ok, results} = TantivyEx.Searcher.search(searcher, "category:/Electronics/Computers", 10)
```

### Understanding Segments and Commits

```elixir
# Documents are added to segments
TantivyEx.IndexWriter.add_document(writer, doc1)  # Goes to segment 1
TantivyEx.IndexWriter.add_document(writer, doc2)  # Goes to segment 1

# Commit makes documents searchable
TantivyEx.IndexWriter.commit(writer)  # Segment 1 becomes visible

# More documents go to new segments
TantivyEx.IndexWriter.add_document(writer, doc3)  # Goes to segment 2
```

### Field Options in Practice

```elixir
# Different field configurations for different use cases
{:ok, schema} = Schema.new()
|> Schema.add_text_field("title", :text_stored)      # Searchable + retrievable
|> Schema.add_text_field("content", :text)           # Searchable only
|> Schema.add_u64_field("timestamp", :fast_stored)   # Fast filtering + retrievable
|> Schema.add_text_field("author", :stored)          # Retrievable only
|> Schema.add_facet_field("category", :facet)        # Hierarchical navigation
```

## Next Steps

Now that you understand the core concepts, explore these guides:

- **[Schema Design Guide](schema.md)** - Design effective schemas
- **[Indexing Guide](indexing.md)** - Master document operations
- **[Search Guide](search.md)** - Learn advanced querying
- **[Performance Tuning](performance-tuning.md)** - Optimize for production
