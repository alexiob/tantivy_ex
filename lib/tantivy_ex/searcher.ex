defmodule TantivyEx.Searcher do
  @moduledoc """
  Searcher for querying a TantivyEx index.
  
  The Searcher provides functionality to search documents in an index
  and retrieve search results.
  """

  alias TantivyEx.{Native, Index}

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
  
  ## Parameters
  
  - `searcher`: The Searcher
  - `query`: The search query string
  - `limit`: Maximum number of results to return (default: 10)
  
  ## Examples
  
      iex> {:ok, results} = TantivyEx.Searcher.search(searcher, "hello world", 10)
      iex> is_list(results)
      true
  """
  @spec search(t(), String.t(), pos_integer()) :: {:ok, [search_result()]} | {:error, String.t()}
  def search(searcher, query, limit \\ 10) do
    case Native.searcher_search(searcher, query, limit) do
      {:error, reason} -> {:error, reason}
      results_json when is_binary(results_json) -> 
        case Jason.decode(results_json) do
          {:ok, results} -> {:ok, results}
          {:error, _} -> {:error, "Failed to parse search results"}
        end
      results -> {:ok, results}
    end
  rescue
    e -> {:error, "Failed to search: #{inspect(e)}"}
  end

  @doc """
  Searches the index and returns only document IDs.
  
  This is more efficient when you only need document IDs and not the full documents.
  
  ## Parameters
  
  - `searcher`: The Searcher
  - `query`: The search query string
  - `limit`: Maximum number of results to return (default: 10)
  
  ## Examples
  
      iex> {:ok, doc_ids} = TantivyEx.Searcher.search_ids(searcher, "hello world", 10)
      iex> is_list(doc_ids)
      true
  """
  @spec search_ids(t(), String.t(), pos_integer()) :: {:ok, [pos_integer()]} | {:error, String.t()}
  def search_ids(searcher, query, limit \\ 10) do
    case search(searcher, query, limit) do
      {:ok, results} -> 
        doc_ids = Enum.map(results, fn result -> 
          case result do
            %{"doc_id" => doc_id} -> doc_id
            _ -> nil
          end
        end)
        |> Enum.filter(&(&1 != nil))
        {:ok, doc_ids}
      {:error, reason} -> {:error, reason}
    end
  end
end
