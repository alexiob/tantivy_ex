defmodule TantivyEx.Facet do
  @moduledoc """
  Faceted search functionality for TantivyEx.

  Facets are hierarchical categories that allow for sophisticated navigation and filtering
  of search results. This module provides comprehensive faceted search capabilities including
  facet collection, drilling down, and hierarchical navigation.

  ## Examples

      # Basic facet collection
      {:ok, facet_collector} = TantivyEx.Facet.collector_for_field("category")
      :ok = TantivyEx.Facet.add_facet(facet_collector, "/electronics")
      {:ok, facet_counts} = TantivyEx.Facet.search(searcher, query, facet_collector)

      # Get top facets
      top_facets = TantivyEx.Facet.get_top_k(facet_counts, "/electronics", 10)

      # Hierarchical facet navigation
      child_facets = TantivyEx.Facet.get_children(facet_counts, "/electronics/computers")

      # Facet filtering with boolean queries
      facet_query = TantivyEx.Facet.facet_term_query("category", "/electronics/laptops")
      {:ok, filtered_results} = TantivyEx.Searcher.search(searcher, facet_query, 100, true)

  ## Facet Structure

  Facets are hierarchical paths separated by forward slashes:
  - `/electronics` - Top level category
  - `/electronics/computers` - Subcategory
  - `/electronics/computers/laptops` - Sub-subcategory

  Each level can be searched and counted independently, allowing for drill-down navigation.
  """

  alias TantivyEx.Native

  @doc """
  Creates a new facet collector for the specified field.

  ## Parameters
  - `field_name` - The name of the facet field to collect on

  ## Returns
  - `{:ok, collector_ref}` on success
  - `{:error, reason}` on failure

  ## Example
      {:ok, collector} = TantivyEx.Facet.collector_for_field("category")
  """
  @spec collector_for_field(String.t()) :: {:ok, reference()} | {:error, String.t()}
  def collector_for_field(field_name) when is_binary(field_name) do
    case Native.facet_collector_for_field(field_name) do
      {:ok, collector_ref} -> {:ok, collector_ref}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, "Failed to create facet collector: #{inspect(e)}"}
  end

  @doc """
  Adds a facet path to the collector for counting.

  ## Parameters
  - `collector_ref` - Reference to the facet collector
  - `facet_path` - The hierarchical facet path (e.g., "/electronics/computers")

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure

  ## Example
      :ok = TantivyEx.Facet.add_facet(collector, "/electronics")
      :ok = TantivyEx.Facet.add_facet(collector, "/electronics/computers")
  """
  @spec add_facet(reference(), String.t()) :: :ok | {:error, String.t()}
  def add_facet(collector_ref, facet_path)
      when is_reference(collector_ref) and is_binary(facet_path) do
    case Native.facet_collector_add_facet(collector_ref, facet_path) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, "Failed to add facet: #{inspect(e)}"}
  end

  @doc """
  Performs a search with facet collection.

  ## Parameters
  - `searcher_ref` - Reference to the searcher
  - `query_ref` - Reference to the query
  - `collector_ref` - Reference to the facet collector

  ## Returns
  - `{:ok, facet_counts}` on success where facet_counts is a map
  - `{:error, reason}` on failure

  ## Example
      {:ok, facet_counts} = TantivyEx.Facet.search(searcher, query, collector)
  """
  @spec search(reference(), reference(), reference()) :: {:ok, map()} | {:error, String.t()}
  def search(searcher_ref, query_ref, collector_ref)
      when is_reference(searcher_ref) and is_reference(query_ref) and is_reference(collector_ref) do
    case Native.facet_search(searcher_ref, query_ref, collector_ref) do
      {:ok, results_json} when is_binary(results_json) ->
        case Jason.decode(results_json) do
          {:ok, results} -> {:ok, results}
          {:error, _} -> {:error, "Failed to parse facet results"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, "Failed to perform faceted search: #{inspect(e)}"}
  end

  @doc """
  Gets the top K facets for a given facet path.

  ## Parameters
  - `facet_counts` - The facet counts result from search/3
  - `facet_path` - The parent facet path to get children for
  - `k` - Number of top facets to return

  ## Returns
  - List of tuples `{facet_path, count}` sorted by count descending

  ## Example
      top_categories = TantivyEx.Facet.get_top_k(facet_counts, "/electronics", 5)
      # Returns: [{"/electronics/computers", 150}, {"/electronics/phones", 89}, ...]
  """
  @spec get_top_k(map(), String.t(), non_neg_integer()) :: [{String.t(), non_neg_integer()}]
  def get_top_k(facet_counts, facet_path, k)
      when is_map(facet_counts) and is_binary(facet_path) and is_integer(k) and k >= 0 do
    case Map.get(facet_counts, facet_path) do
      nil ->
        []

      children when is_map(children) ->
        children
        |> Enum.to_list()
        |> Enum.sort_by(fn {_facet, count} -> count end, :desc)
        |> Enum.take(k)

      _ ->
        []
    end
  end

  @doc """
  Gets all child facets for a given parent facet path.

  ## Parameters
  - `facet_counts` - The facet counts result from search/3
  - `parent_path` - The parent facet path

  ## Returns
  - List of tuples `{facet_path, count}` for all children

  ## Example
      children = TantivyEx.Facet.get_children(facet_counts, "/electronics")
      # Returns: [{"/electronics/computers", 150}, {"/electronics/phones", 89}, ...]
  """
  @spec get_children(map(), String.t()) :: [{String.t(), non_neg_integer()}]
  def get_children(facet_counts, parent_path)
      when is_map(facet_counts) and is_binary(parent_path) do
    case Map.get(facet_counts, parent_path) do
      nil -> []
      children when is_map(children) -> Enum.to_list(children)
      _ -> []
    end
  end

  @doc """
  Creates a term query for filtering by a specific facet.

  ## Parameters
  - `field_name` - The facet field name
  - `facet_path` - The facet path to filter by

  ## Returns
  - `{:ok, query_ref}` on success
  - `{:error, reason}` on failure

  ## Example
      {:ok, facet_query} = TantivyEx.Facet.facet_term_query("category", "/electronics/laptops")
      {:ok, results} = TantivyEx.Searcher.search(searcher, facet_query, 100, true)
  """
  @spec facet_term_query(String.t(), String.t()) :: {:ok, reference()} | {:error, String.t()}
  def facet_term_query(field_name, facet_path)
      when is_binary(field_name) and is_binary(facet_path) do
    case Native.facet_term_query(field_name, facet_path) do
      {:ok, query_ref} -> {:ok, query_ref}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, "Failed to create facet term query: #{inspect(e)}"}
  end

  @doc """
  Creates a multi-facet boolean query for filtering by multiple facets.

  ## Parameters
  - `field_name` - The facet field name
  - `facet_paths` - List of facet paths to filter by
  - `occur` - How to combine the facets (:should, :must, :must_not)

  ## Returns
  - `{:ok, query_ref}` on success
  - `{:error, reason}` on failure

  ## Example
      facets = ["/electronics/laptops", "/electronics/tablets"]
      {:ok, multi_query} = TantivyEx.Facet.multi_facet_query("category", facets, :should)
  """
  @spec multi_facet_query(String.t(), [String.t()], atom()) ::
          {:ok, reference()} | {:error, String.t()}
  def multi_facet_query(field_name, facet_paths, occur)
      when is_binary(field_name) and is_list(facet_paths) and is_atom(occur) do
    occur_str =
      case occur do
        :should -> "should"
        :must -> "must"
        :must_not -> "must_not"
        _ -> "should"
      end

    case Native.facet_multi_query(field_name, facet_paths, occur_str) do
      {:ok, query_ref} -> {:ok, query_ref}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, "Failed to create multi-facet query: #{inspect(e)}"}
  end

  @doc """
  Gets the total count for a specific facet path.

  ## Parameters
  - `facet_counts` - The facet counts result from search/3
  - `facet_path` - The facet path to get count for

  ## Returns
  - The count as integer, or 0 if not found

  ## Example
      count = TantivyEx.Facet.get_count(facet_counts, "/electronics/laptops")
  """
  @spec get_count(map(), String.t()) :: non_neg_integer()
  def get_count(facet_counts, facet_path) when is_map(facet_counts) and is_binary(facet_path) do
    facet_counts
    |> get_nested_count(String.split(facet_path, "/", trim: true))
  end

  # Helper function to navigate nested facet structure
  defp get_nested_count(_counts, []), do: 0

  defp get_nested_count(counts, [segment]) when is_map(counts) do
    case Map.get(counts, "/" <> segment) do
      count when is_integer(count) -> count
      _ -> 0
    end
  end

  defp get_nested_count(counts, [segment | rest]) when is_map(counts) do
    case Map.get(counts, "/" <> segment) do
      nested when is_map(nested) -> get_nested_count(nested, rest)
      _ -> 0
    end
  end

  defp get_nested_count(_, _), do: 0

  @doc """
  Creates a facet from a text path.

  ## Parameters
  - `facet_path` - The facet path string

  ## Returns
  - `{:ok, facet_ref}` on success
  - `{:error, reason}` on failure

  ## Example
      {:ok, facet} = TantivyEx.Facet.from_text("/electronics/laptops")
  """
  @spec from_text(String.t()) :: {:ok, reference()} | {:error, String.t()}
  def from_text(facet_path) when is_binary(facet_path) do
    case Native.facet_from_text(facet_path) do
      {:ok, facet_ref} -> {:ok, facet_ref}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, "Failed to create facet from text: #{inspect(e)}"}
  end

  @doc """
  Gets the string representation of a facet.

  ## Parameters
  - `facet_ref` - Reference to the facet

  ## Returns
  - `{:ok, facet_string}` on success
  - `{:error, reason}` on failure

  ## Example
      {:ok, path} = TantivyEx.Facet.to_string(facet_ref)
  """
  @spec to_string(reference()) :: {:ok, String.t()} | {:error, String.t()}
  def to_string(facet_ref) when is_reference(facet_ref) do
    case Native.facet_to_string(facet_ref) do
      {:ok, facet_string} -> {:ok, facet_string}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, "Failed to convert facet to string: #{inspect(e)}"}
  end
end
