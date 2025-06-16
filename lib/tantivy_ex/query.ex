defmodule TantivyEx.Query do
  @moduledoc """
  Comprehensive query building functionality for TantivyEx.

  This module provides functions to build various types of queries including:
  - Term queries for exact matches
  - Phrase queries for multi-word exact phrases
  - Range queries for numeric and date ranges
  - Boolean queries for combining multiple queries with AND, OR, NOT logic
  - Fuzzy queries for approximate matching
  - Wildcard and regex queries for pattern matching
  - More-like-this queries for similarity search
  - Phrase prefix queries for autocomplete-style search
  - Exists queries to check field presence

  ## Query Parser

  The query parser allows you to use a Lucene-style query syntax:

      # Create a parser for text fields
      {:ok, parser} = TantivyEx.Query.parser(schema, ["title", "body"])

      # Parse complex queries
      {:ok, query} = TantivyEx.Query.parse(parser, "title:hello AND body:world")
      {:ok, query} = TantivyEx.Query.parse(parser, "title:\"exact phrase\"")
      {:ok, query} = TantivyEx.Query.parse(parser, "price:[100 TO 500]")

  ## Building Queries Programmatically

      # Term query - exact match
      {:ok, query} = TantivyEx.Query.term(schema, "title", "hello")

      # Phrase query - exact phrase
      {:ok, query} = TantivyEx.Query.phrase(schema, "title", ["hello", "world"])

      # Range query - numeric range
      {:ok, query} = TantivyEx.Query.range_u64(schema, "price", 100, 500)

      # Boolean query - combine multiple queries
      {:ok, term1} = TantivyEx.Query.term(schema, "title", "hello")
      {:ok, term2} = TantivyEx.Query.term(schema, "body", "world")
      {:ok, query} = TantivyEx.Query.boolean([term1], [term2], [])

      # Fuzzy query - approximate matching
      {:ok, query} = TantivyEx.Query.fuzzy(schema, "title", "hello", 2)
  """

  alias TantivyEx.{Native, Schema}

  @type t :: reference()
  @type parser :: reference()

  @doc """
  Creates a term query for exact matching.

  Term queries match documents where the specified field contains the exact term.

  ## Parameters

  - `schema`: The schema containing the field
  - `field_name`: The name of the field to search
  - `term_value`: The exact term to match

  ## Examples

      iex> {:ok, query} = TantivyEx.Query.term(schema, "title", "hello")
      iex> is_reference(query)
      true
  """
  @spec term(Schema.t(), String.t(), any()) :: {:ok, t()} | {:error, String.t()}
  def term(schema, field_name, term_value) when is_binary(field_name) do
    # Convert the term value to a string if it's not already a string
    term_str = if is_binary(term_value), do: term_value, else: to_string(term_value)

    case Native.query_term(schema, field_name, term_str) do
      {:error, error_reason} -> {:error, "Failed to create term query: #{error_reason}"}
      query_ref -> {:ok, query_ref}
    end
  rescue
    e -> {:error, "Failed to create term query: #{inspect(e)}"}
  end

  # Query Parser Functions

  @doc """
  Creates a new query parser for the given index and default fields.

  The query parser allows parsing Lucene-style query strings.

  ## Parameters

  - `index`: The index to use for field resolution
  - `default_fields`: List of field names to search by default

  ## Examples

      iex> {:ok, parser} = TantivyEx.Query.parser(index, ["title", "body"])
      iex> is_reference(parser)
      true
  """
  @spec parser(TantivyEx.Index.t(), [String.t()]) :: {:ok, parser()} | {:error, String.t()}
  def parser(index, default_fields) when is_list(default_fields) do
    case Native.query_parser_new(index, default_fields) do
      {:error, reason} -> {:error, reason}
      parser_ref -> {:ok, parser_ref}
    end
  rescue
    e -> {:error, "Failed to create query parser: #{inspect(e)}"}
  end

  @doc """
  Parses a query string using the given parser.

  Supports Lucene-style query syntax including:
  - Field-specific queries: `title:hello`
  - Phrase queries: `title:"hello world"`
  - Range queries: `price:[100 TO 500]`
  - Boolean operators: `title:hello AND body:world`
  - Wildcards: `title:hel*`
  - Fuzzy queries: `title:hello~2`

  ## Parameters

  - `parser`: The query parser
  - `query_str`: The query string to parse

  ## Examples

      iex> {:ok, query} = TantivyEx.Query.parse(parser, "title:hello AND body:world")
      iex> is_reference(query)
      true
  """
  @spec parse(parser(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse(parser, query_str) when is_binary(query_str) do
    case Native.query_parser_parse(parser, query_str) do
      {:error, reason} -> {:error, reason}
      query_ref -> {:ok, query_ref}
    end
  rescue
    e -> {:error, "Failed to parse query: #{inspect(e)}"}
  end

  @doc """
  Creates a phrase query for exact phrase matching.

  Phrase queries match documents where the specified field contains the exact sequence of terms.

  ## Parameters

  - `schema`: The schema containing the field
  - `field_name`: The name of the field to search
  - `phrase_terms`: List of terms that must appear in order

  ## Examples

      iex> {:ok, query} = TantivyEx.Query.phrase(schema, "title", ["hello", "world"])
      iex> is_reference(query)
      true
  """
  @spec phrase(Schema.t(), String.t(), [String.t()]) :: {:ok, t()} | {:error, String.t()}
  def phrase(schema, field_name, phrase_terms)
      when is_binary(field_name) and is_list(phrase_terms) do
    # Phrase queries need at least two terms in Tantivy
    if length(phrase_terms) < 2 do
      # For single term phrase, fallback to a term query for the first term
      if length(phrase_terms) == 1 do
        term(schema, field_name, List.first(phrase_terms))
      else
        {:error, "Phrase query requires at least one term"}
      end
    else
      case Native.query_phrase(schema, field_name, phrase_terms) do
        {:error, reason} -> {:error, reason}
        query_ref -> {:ok, query_ref}
      end
    end
  rescue
    e -> {:error, "Failed to create phrase query: #{inspect(e)}"}
  end

  # Range Queries

  @doc """
  Creates a range query for u64 fields.

  Range queries match documents where the field value falls within the specified range.

  ## Parameters

  - `schema`: The schema containing the field
  - `field_name`: The name of the numeric field
  - `start_value`: The start of the range (nil for unbounded)
  - `end_value`: The end of the range (nil for unbounded)

  ## Examples

      iex> {:ok, query} = TantivyEx.Query.range_u64(schema, "price", 100, 500)
      iex> {:ok, query} = TantivyEx.Query.range_u64(schema, "price", 100, nil)  # >= 100
      iex> {:ok, query} = TantivyEx.Query.range_u64(schema, "price", nil, 500)  # <= 500
  """
  @spec range_u64(Schema.t(), String.t(), non_neg_integer() | nil, non_neg_integer() | nil) ::
          {:ok, t()} | {:error, String.t()}
  def range_u64(schema, field_name, start_value, end_value) when is_binary(field_name) do
    case Native.query_range_u64(schema, field_name, start_value, end_value) do
      {:error, reason} -> {:error, reason}
      query_ref -> {:ok, query_ref}
    end
  rescue
    e -> {:error, "Failed to create u64 range query: #{inspect(e)}"}
  end

  @doc """
  Creates a range query for i64 fields.

  ## Parameters

  - `schema`: The schema containing the field
  - `field_name`: The name of the numeric field
  - `start_value`: The start of the range (nil for unbounded)
  - `end_value`: The end of the range (nil for unbounded)
  """
  @spec range_i64(Schema.t(), String.t(), integer() | nil, integer() | nil) ::
          {:ok, t()} | {:error, String.t()}
  def range_i64(schema, field_name, start_value, end_value) when is_binary(field_name) do
    case Native.query_range_i64(schema, field_name, start_value, end_value) do
      {:error, reason} -> {:error, reason}
      query_ref -> {:ok, query_ref}
    end
  rescue
    e -> {:error, "Failed to create i64 range query: #{inspect(e)}"}
  end

  @doc """
  Creates a range query for f64 fields.

  ## Parameters

  - `schema`: The schema containing the field
  - `field_name`: The name of the numeric field
  - `start_value`: The start of the range (nil for unbounded)
  - `end_value`: The end of the range (nil for unbounded)
  """
  @spec range_f64(Schema.t(), String.t(), float() | nil, float() | nil) ::
          {:ok, t()} | {:error, String.t()}
  def range_f64(schema, field_name, start_value, end_value) when is_binary(field_name) do
    case Native.query_range_f64(schema, field_name, start_value, end_value) do
      {:error, reason} -> {:error, reason}
      query_ref -> {:ok, query_ref}
    end
  rescue
    e -> {:error, "Failed to create f64 range query: #{inspect(e)}"}
  end

  # Boolean Queries

  @doc """
  Creates a boolean query combining multiple queries with AND, OR, NOT logic.

  Boolean queries allow complex combinations of other queries:
  - `must_queries`: All queries in this list must match (AND)
  - `should_queries`: At least one query in this list should match (OR)
  - `must_not_queries`: No queries in this list should match (NOT)

  ## Parameters

  - `must_queries`: List of queries that must all match
  - `should_queries`: List of queries where at least one should match
  - `must_not_queries`: List of queries that must not match

  ## Examples

      iex> {:ok, term1} = TantivyEx.Query.term(schema, "title", "hello")
      iex> {:ok, term2} = TantivyEx.Query.term(schema, "body", "world")
      iex> {:ok, term3} = TantivyEx.Query.term(schema, "category", "spam")
      iex> {:ok, query} = TantivyEx.Query.boolean([term1], [term2], [term3])
  """
  @spec boolean([t()], [t()], [t()]) :: {:ok, t()} | {:error, String.t()}
  def boolean(must_queries, should_queries, must_not_queries)
      when is_list(must_queries) and is_list(should_queries) and is_list(must_not_queries) do
    case Native.query_boolean(must_queries, should_queries, must_not_queries) do
      {:error, reason} -> {:error, reason}
      query_ref -> {:ok, query_ref}
    end
  rescue
    e -> {:error, "Failed to create boolean query: #{inspect(e)}"}
  end

  # Advanced Query Types

  @doc """
  Creates a fuzzy query for approximate matching.

  Fuzzy queries match terms that are similar to the specified term, allowing for typos
  and minor spelling differences.

  ## Parameters

  - `schema`: The schema containing the field
  - `field_name`: The name of the field to search
  - `term_value`: The term to match approximately
  - `distance`: Maximum edit distance (default: 2)
  - `prefix`: Whether to require exact prefix match (default: true)

  ## Examples

      iex> {:ok, query} = TantivyEx.Query.fuzzy(schema, "title", "hello", 2, true)
      iex> is_reference(query)
      true
  """
  @spec fuzzy(Schema.t(), String.t(), String.t(), non_neg_integer(), boolean()) ::
          {:ok, t()} | {:error, String.t()}
  def fuzzy(schema, field_name, term_value, distance \\ 2, prefix \\ true)
      when is_binary(field_name) and is_binary(term_value) and is_integer(distance) and
             is_boolean(prefix) do
    case Native.query_fuzzy(schema, field_name, term_value, distance, prefix) do
      {:error, reason} -> {:error, reason}
      query_ref -> {:ok, query_ref}
    end
  rescue
    e -> {:error, "Failed to create fuzzy query: #{inspect(e)}"}
  end

  @doc """
  Creates a wildcard query for pattern matching.

  Wildcard queries support `*` (matches any sequence of characters) and
  `?` (matches any single character).

  ## Parameters

  - `schema`: The schema containing the field
  - `field_name`: The name of the field to search
  - `pattern`: The wildcard pattern

  ## Examples

      iex> {:ok, query} = TantivyEx.Query.wildcard(schema, "title", "hel*")
      iex> {:ok, query} = TantivyEx.Query.wildcard(schema, "title", "h?llo")
  """
  @spec wildcard(Schema.t(), String.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def wildcard(schema, field_name, pattern) when is_binary(field_name) and is_binary(pattern) do
    case Native.query_wildcard(schema, field_name, pattern) do
      {:error, reason} -> {:error, reason}
      query_ref -> {:ok, query_ref}
    end
  rescue
    e -> {:error, "Failed to create wildcard query: #{inspect(e)}"}
  end

  @doc """
  Creates a regex query for advanced pattern matching.

  Regex queries allow full regular expression matching against field values.

  ## Parameters

  - `schema`: The schema containing the field
  - `field_name`: The name of the field to search
  - `pattern`: The regular expression pattern

  ## Examples

      iex> {:ok, query} = TantivyEx.Query.regex(schema, "title", "h[ae]llo")
      iex> {:ok, query} = TantivyEx.Query.regex(schema, "email", ".*@example\\.com")
  """
  @spec regex(Schema.t(), String.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def regex(schema, field_name, pattern) when is_binary(field_name) and is_binary(pattern) do
    case Native.query_regex(schema, field_name, pattern) do
      {:error, reason} -> {:error, reason}
      query_ref -> {:ok, query_ref}
    end
  rescue
    e -> {:error, "Failed to create regex query: #{inspect(e)}"}
  end

  @doc """
  Creates a phrase prefix query for autocomplete-style search.

  Phrase prefix queries match phrases where the last term is treated as a prefix.
  Useful for autocomplete functionality.

  ## Parameters

  - `schema`: The schema containing the field
  - `field_name`: The name of the field to search
  - `phrase_terms`: List of terms, where the last one is treated as a prefix
  - `max_expansions`: Maximum number of terms to expand the prefix to (default: 50)

  ## Examples

      iex> {:ok, query} = TantivyEx.Query.phrase_prefix(schema, "title", ["hello", "wor"], 50)
  """
  @spec phrase_prefix(Schema.t(), String.t(), [String.t()], pos_integer()) ::
          {:ok, t()} | {:error, String.t()}
  def phrase_prefix(schema, field_name, phrase_terms, max_expansions \\ 50)
      when is_binary(field_name) and is_list(phrase_terms) and is_integer(max_expansions) do
    case Native.query_phrase_prefix(schema, field_name, phrase_terms, max_expansions) do
      {:error, reason} -> {:error, reason}
      query_ref -> {:ok, query_ref}
    end
  rescue
    e -> {:error, "Failed to create phrase prefix query: #{inspect(e)}"}
  end

  @doc """
  Creates an exists query to check if a field has any value.

  Exists queries match documents where the specified field contains any value.

  ## Parameters

  - `schema`: The schema containing the field
  - `field_name`: The name of the field to check

  ## Examples

      iex> {:ok, query} = TantivyEx.Query.exists(schema, "email")
  """
  @spec exists(Schema.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def exists(schema, field_name) when is_binary(field_name) do
    # Check if the field exists in the schema first
    try do
      if Schema.field_exists?(schema, field_name) do
        case Native.query_exists(schema, field_name) do
          {:error, reason} -> {:error, reason}
          query_ref -> {:ok, query_ref}
        end
      else
        {:error, "Field '#{field_name}' not found in schema"}
      end
    catch
      # Fallback for any errors
      _, e -> {:error, "Failed to create exists query: #{inspect(e)}"}
    end
  rescue
    e -> {:error, "Failed to create exists query: #{inspect(e)}"}
  end

  # Special Queries

  @doc """
  Creates a query that matches all documents.

  ## Examples

      iex> query = TantivyEx.Query.all()
      iex> is_reference(query)
      true
  """
  @spec all() :: {:ok, t()}
  def all() do
    {:ok, Native.query_all()}
  end

  @doc """
  Creates a query that matches no documents.

  ## Examples

      iex> {:ok, query} = TantivyEx.Query.empty()
      iex> is_reference(query)
      true
  """
  @spec empty() :: {:ok, t()}
  def empty() do
    {:ok, Native.query_empty()}
  end

  @doc """
  Creates a more-like-this query for similarity search.

  More-like-this queries find documents similar to a given document or text.

  ## Parameters

  - `schema`: The schema containing field definitions
  - `document`: The document as JSON string to find similar documents to
  - `options`: Keyword list of options including:
    - `min_doc_frequency`: Minimum document frequency for terms (default: 5)
    - `max_doc_frequency`: Maximum document frequency for terms (default: unlimited)
    - `min_term_frequency`: Minimum term frequency in document (default: 2)
    - `max_query_terms`: Maximum number of query terms (default: 25)
    - `min_word_length`: Minimum word length (default: 0)
    - `max_word_length`: Maximum word length (default: unlimited)
    - `boost_factor`: Boost factor for scoring (default: 1.0)

  ## Examples

      iex> doc = Jason.encode!(%{"title" => "Machine Learning", "body" => "AI and algorithms"})
      iex> {:ok, query} = TantivyEx.Query.more_like_this(schema, doc, min_doc_frequency: 2, max_query_terms: 10)
  """
  @spec more_like_this(Schema.t(), map() | String.t(), keyword()) ::
          {:ok, t()} | {:error, String.t()}
  def more_like_this(schema, document, options \\ []) when is_list(options) do
    document_json = if is_binary(document), do: document, else: Jason.encode!(document)
    min_doc_frequency = Keyword.get(options, :min_doc_frequency)
    max_doc_frequency = Keyword.get(options, :max_doc_frequency)
    min_term_frequency = Keyword.get(options, :min_term_frequency)
    max_query_terms = Keyword.get(options, :max_query_terms)
    min_word_length = Keyword.get(options, :min_word_length)
    max_word_length = Keyword.get(options, :max_word_length)
    boost_factor = Keyword.get(options, :boost_factor)

    case Native.query_more_like_this(
           schema,
           document_json,
           min_doc_frequency,
           max_doc_frequency,
           min_term_frequency,
           max_query_terms,
           min_word_length,
           max_word_length,
           boost_factor
         ) do
      {:error, reason} -> {:error, reason}
      query_ref -> {:ok, query_ref}
    end
  rescue
    e -> {:error, "Failed to create more-like-this query: #{inspect(e)}"}
  end

  # Facet Queries

  @doc """
  Creates a facet term query for exact facet matching.

  Facet queries are optimized for filtering documents by facet values.
  This is the preferred way to query facet fields.

  ## Parameters

  - `schema`: The index schema containing the facet field definition
  - `field_name`: The name of the facet field
  - `facet_value`: The exact facet value to match

  ## Examples

      iex> {:ok, query} = TantivyEx.Query.facet_term(schema, "categories", "electronics")
      iex> is_reference(query)
      true
  """
  @spec facet_term(Schema.t(), String.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def facet_term(schema, field_name, facet_value) when is_binary(field_name) and is_binary(facet_value) do
    case Native.facet_term_query(schema, field_name, facet_value) do
      {:error, reason} -> {:error, reason}
      query_ref -> {:ok, query_ref}
    end
  rescue
    e -> {:error, "Failed to create facet term query: #{inspect(e)}"}
  end
end
