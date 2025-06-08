defmodule TantivyEx.Searcher do
  @moduledoc """
  Searcher for querying a TantivyEx index.

  The Searcher provides functionality to search documents in an index
  and retrieve search results using various query types including:
  - Simple string queries (parsed automatically)
  - Complex query objects built with TantivyEx.Query
  - Boolean combinations of multiple queries
  """

  alias TantivyEx.{Native, Index, Query}

  @type t :: reference()
  @type search_result :: %{
          score: float(),
          doc_id: pos_integer(),
          document: map()
        }

  @doc """
  Creates a new Searcher for the given index.

  ## Parameters

  - `index`: The index to search

  ## Examples

      iex> {:ok, searcher} = TantivyEx.Searcher.new(index)
      iex> is_reference(searcher)
      true
  """
  @spec new(Index.t()) :: {:ok, t()} | {:error, String.t()}
  def new(index) do
    case Native.index_reader(index) do
      {:error, reason} -> {:error, reason}
      searcher -> {:ok, searcher}
    end
  rescue
    e -> {:error, "Failed to create searcher: #{inspect(e)}"}
  end

  @doc """
  Searches the index with the given query.

  This function supports both string queries (which are parsed using AllQuery for now)
  and Query objects created with TantivyEx.Query functions.

  ## Parameters

  - `searcher`: The Searcher
  - `query`: The search query (string or Query.t())
  - `limit`: Maximum number of results to return (default: 10)
  - `include_docs`: Whether to include full document content (default: true)

  ## Examples

      # Simple string search (legacy - uses AllQuery)
      iex> {:ok, results} = TantivyEx.Searcher.search(searcher, "hello world", 10)

      # Using Query objects for precise control
      iex> {:ok, query} = TantivyEx.Query.term(schema, "title", "hello")
      iex> {:ok, results} = TantivyEx.Searcher.search(searcher, query, 10)

      # Boolean query example
      iex> {:ok, term1} = TantivyEx.Query.term(schema, "title", "hello")
      iex> {:ok, term2} = TantivyEx.Query.term(schema, "body", "world")
      iex> {:ok, boolean_query} = TantivyEx.Query.boolean([term1], [term2], [])
      iex> {:ok, results} = TantivyEx.Searcher.search(searcher, boolean_query, 10)
  """
  @spec search(t(), String.t() | Query.t(), pos_integer(), boolean()) ::
          {:ok, [search_result()]} | {:error, String.t()}
  def search(searcher, query, limit \\ 10, include_docs \\ true)

  def search(searcher, query, limit, include_docs) when is_binary(query) do
    # Legacy string-based search - uses the old implementation for now
    # In the future, this could parse the string with a default parser
    case Native.searcher_search(searcher, query, limit, include_docs) do
      {:error, reason} ->
        {:error, reason}

      results_json when is_binary(results_json) ->
        case Jason.decode(results_json) do
          {:ok, results} -> {:ok, results}
          {:error, _} -> {:error, "Failed to parse search results"}
        end

      results ->
        {:ok, results}
    end
  rescue
    e -> {:error, "Failed to search: #{inspect(e)}"}
  end

  def search(searcher, query, limit, include_docs) when is_reference(query) do
    # Query object-based search - uses the new enhanced search
    case Native.searcher_search_with_query(searcher, query, limit, include_docs) do
      {:error, reason} ->
        {:error, reason}

      results_json when is_binary(results_json) ->
        case Jason.decode(results_json) do
          {:ok, results} -> {:ok, results}
          {:error, _} -> {:error, "Failed to parse search results"}
        end

      results ->
        {:ok, results}
    end
  rescue
    e -> {:error, "Failed to search with query: #{inspect(e)}"}
  end

  @doc """
  Searches the index and returns only document IDs.

  This is more efficient when you only need document IDs, not the full documents or scores.

  ## Parameters

  - `searcher`: The Searcher
  - `query`: The search query (string or Query.t())
  - `limit`: Maximum number of results to return (default: 10)

  ## Examples

      iex> {:ok, query} = TantivyEx.Query.term(schema, "title", "hello")
      iex> {:ok, doc_ids} = TantivyEx.Searcher.search_ids(searcher, query, 10)
      iex> [1, 5, 3] = doc_ids
  """
  @spec search_ids(t(), String.t() | Query.t(), pos_integer()) ::
          {:ok, [pos_integer()]} | {:error, String.t()}
  def search_ids(searcher, query, limit \\ 10) do
    case search(searcher, query, limit, false) do
      {:ok, results} ->
        doc_ids =
          Enum.map(results, fn result ->
            Map.get(result, "doc_id", 0)
          end)

        {:ok, doc_ids}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Performs a search and returns full documents with metadata.

  This function always includes full document content and is optimized for cases
  where you need the complete document data.

  ## Parameters

  - `searcher`: The Searcher
  - `query`: The search query (Query.t() only - no string queries)
  - `limit`: Maximum number of results to return (default: 10)

  ## Examples

      iex> {:ok, query} = TantivyEx.Query.phrase(schema, "title", ["hello", "world"])
      iex> {:ok, results} = TantivyEx.Searcher.search_documents(searcher, query, 10)
      iex> [%{"score" => 1.0, "doc_id" => 1, "title" => "hello world", "body" => "..."}] = results
  """
  @spec search_documents(t(), Query.t(), pos_integer()) ::
          {:ok, [search_result()]} | {:error, String.t()}
  def search_documents(searcher, query, limit \\ 10) when is_reference(query) do
    search(searcher, query, limit, true)
  end

  @doc """
  Performs a search with a query parser for Lucene-style queries.

  This is a convenience function that creates a parser, parses the query string,
  and performs the search in one call.

  ## Parameters

  - `searcher`: The Searcher
  - `schema`: The schema for field resolution
  - `default_fields`: List of fields to search by default
  - `query_str`: The Lucene-style query string
  - `limit`: Maximum number of results to return (default: 10)
  - `include_docs`: Whether to include full document content (default: true)

  ## Examples

      iex> {:ok, results} = TantivyEx.Searcher.search_with_parser(
      ...>   searcher, schema, ["title", "body"],
      ...>   "title:hello AND body:world", 10
      ...> )
  """
  @spec search_with_parser(t(), Schema.t(), [String.t()], String.t(), pos_integer(), boolean()) ::
          {:ok, [search_result()]} | {:error, String.t()}
  def search_with_parser(
        searcher,
        schema,
        default_fields,
        query_str,
        limit \\ 10,
        include_docs \\ true
      ) do
    with {:ok, parser} <- Query.parser(schema, default_fields),
         {:ok, query} <- Query.parse(parser, query_str),
         {:ok, results} <- search(searcher, query, limit, include_docs) do
      {:ok, results}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
