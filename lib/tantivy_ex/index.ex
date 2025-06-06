defmodule TantivyEx.Index do
  @moduledoc """
  Index management for TantivyEx.
  
  An index is a collection of segments that contain documents and their associated
  search indices.
  """

  alias TantivyEx.{Native, Schema}

  @type t :: reference()

  @doc """
  Creates a new index in the specified directory.
  
  The directory will be created if it doesn't exist. The index metadata
  and segment files will be stored in this directory.
  
  ## Parameters
  
  - `path`: The filesystem path where the index should be created
  - `schema`: The schema defining the structure of documents
  
  ## Examples
  
      iex> schema = TantivyEx.Schema.new()
      iex> schema = TantivyEx.Schema.add_text_field(schema, "title", :text_stored)
      iex> {:ok, index} = TantivyEx.Index.create_in_dir("/tmp/my_index", schema)
      iex> is_reference(index)
      true
  """
  @spec create_in_dir(String.t(), Schema.t()) :: {:ok, t()} | {:error, String.t()}
  def create_in_dir(path, schema) do
    case Native.index_create_in_dir(path, schema) do
      {:error, reason} -> {:error, reason}
      index -> {:ok, index}
    end
  rescue
    e -> {:error, "Failed to create index: #{inspect(e)}"}
  end

  @doc """
  Creates a new index in RAM.
  
  This creates an in-memory index that doesn't persist to disk.
  Useful for testing or temporary indices.
  
  ## Parameters
  
  - `schema`: The schema defining the structure of documents
  
  ## Examples
  
      iex> schema = TantivyEx.Schema.new()
      iex> schema = TantivyEx.Schema.add_text_field(schema, "title", :text_stored)
      iex> {:ok, index} = TantivyEx.Index.create_in_ram(schema)
      iex> is_reference(index)
      true
  """
  @spec create_in_ram(Schema.t()) :: {:ok, t()} | {:error, String.t()}
  def create_in_ram(schema) do
    case Native.index_create_in_ram(schema) do
      {:error, reason} -> {:error, reason}
      index -> {:ok, index}
    end
  rescue
    e -> {:error, "Failed to create RAM index: #{inspect(e)}"}
  end
end
