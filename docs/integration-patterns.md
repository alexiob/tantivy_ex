# Integration Patterns

This guide covers common patterns for integrating TantivyEx into your Elixir applications, from simple GenServer wrappers to complex Phoenix LiveView implementations.

## GenServer-based Search Service

A GenServer provides a stateful wrapper around your search index with automatic management and background operations:

```elixir
defmodule MyApp.SearchService do
  use GenServer
  require Logger
  alias TantivyEx.{Index, IndexWriter, Searcher}

  @index_path "/var/lib/myapp/search_index"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API
  def search(query, limit \\ 10) do
    GenServer.call(__MODULE__, {:search, query, limit}, 10_000)
  end

  def add_document(document) do
    GenServer.call(__MODULE__, {:add_document, document})
  end

  def add_documents(documents) when is_list(documents) do
    GenServer.call(__MODULE__, {:add_documents, documents})
  end

  def commit do
    GenServer.call(__MODULE__, :commit)
  end

  def reload_index do
    GenServer.call(__MODULE__, :reload_index)
  end

  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # GenServer Callbacks
  def init(_opts) do
    Logger.info("Starting SearchService")

    case load_index() do
      {:ok, index} ->
        schedule_auto_commit()
        state = %{
          index: index,
          uncommitted_changes: false,
          last_commit: DateTime.utc_now(),
          document_count: 0
        }
        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to load search index: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  def handle_call({:search, query, limit}, _from, state) do
    result = perform_search(state.index, query, limit)
    {:reply, result, state}
  end

  def handle_call({:add_document, document}, _from, state) do
    case add_single_document(state.index, document) do
      :ok ->
        new_state = %{
          state |
          uncommitted_changes: true,
          document_count: state.document_count + 1
        }
        {:reply, :ok, new_state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:add_documents, documents}, _from, state) do
    case add_multiple_documents(state.index, documents) do
      :ok ->
        new_state = %{
          state |
          uncommitted_changes: true,
          document_count: state.document_count + length(documents)
        }
        {:reply, :ok, new_state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:commit, _from, state) do
    case commit_changes(state.index) do
      :ok ->
        new_state = %{
          state |
          uncommitted_changes: false,
          last_commit: DateTime.utc_now()
        }
        {:reply, :ok, new_state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:reload_index, _from, state) do
    case load_index() do
      {:ok, new_index} ->
        new_state = %{
          state |
          index: new_index,
          uncommitted_changes: false,
          last_commit: DateTime.utc_now()
        }
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:get_stats, _from, state) do
    stats = %{
      uncommitted_changes: state.uncommitted_changes,
      last_commit: state.last_commit,
      document_count: state.document_count,
      uptime: calculate_uptime()
    }
    {:reply, stats, state}
  end

  # Auto-commit every 30 seconds if there are uncommitted changes
  def handle_info(:auto_commit, %{uncommitted_changes: true} = state) do
    Logger.debug("Auto-committing search index")
    commit_changes(state.index)
    schedule_auto_commit()

    new_state = %{
      state |
      uncommitted_changes: false,
      last_commit: DateTime.utc_now()
    }
    {:noreply, new_state}
  end

  def handle_info(:auto_commit, state) do
    schedule_auto_commit()
    {:noreply, state}
  end

  # Private functions
  defp load_index do
    case File.exists?(@index_path) do
      true ->
        Logger.info("Opening existing search index at #{@index_path}")
        Index.open(@index_path)
      false ->
        Logger.info("Creating new search index at #{@index_path}")
        create_new_index()
    end
  end

  defp create_new_index do
    {:ok, schema} = create_schema()
    Index.create_in_dir(@index_path, schema)
  end

  defp create_schema do
    alias TantivyEx.Schema

    schema = Schema.new()
    schema = Schema.add_text_field(schema, "title", :text_stored)
    schema = Schema.add_text_field(schema, "content", :text)
    schema = Schema.add_text_field(schema, "author", :text_stored)
    schema = Schema.add_u64_field(schema, "timestamp", :fast_stored)
    schema = Schema.add_facet_field(schema, "category", :facet)
    {:ok, schema}
  end

  defp perform_search(index, query, limit) do
    {:ok, searcher} = Searcher.new(index)
    case Searcher.search(searcher, query, limit) do
      {:ok, results} ->
        Logger.debug("Search for '#{query}' returned #{length(results)} results")
        {:ok, results}

      {:error, reason} ->
        Logger.warning("Search failed for query '#{query}': #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp add_single_document(index, document) do
    {:ok, writer} = IndexWriter.new(index)
    IndexWriter.add_document(writer, document)
  end

  defp add_multiple_documents(index, documents) do
    {:ok, writer} = IndexWriter.new(index)

    Enum.reduce_while(documents, :ok, fn doc, _acc ->
      case IndexWriter.add_document(writer, doc) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp commit_changes(index) do
    {:ok, writer} = IndexWriter.new(index)
    IndexWriter.commit(writer)
  end

  defp schedule_auto_commit do
    Process.send_after(self(), :auto_commit, 30_000)
  end

  defp calculate_uptime do
    # Simple uptime calculation - you might want to store start_time in state
    DateTime.utc_now()
  end
end
```

## Phoenix Integration

### Search Controller

```elixir
defmodule MyAppWeb.SearchController do
  use MyAppWeb, :controller
  alias MyApp.SearchService
  require Logger

  plug :validate_search_params when action in [:search]

  def search(conn, %{"q" => query} = params) do
    limit = parse_limit(params)
    page = parse_page(params)

    case SearchService.search(query, limit * page) do
      {:ok, all_results} ->
        {results, pagination} = paginate_results(all_results, page, limit)

        render(conn, :search, %{
          query: query,
          results: results,
          pagination: pagination,
          total: length(all_results)
        })

      {:error, reason} ->
        Logger.warning("Search failed: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Search failed. Please try again.")
        |> render(:search, %{
          query: query,
          results: [],
          pagination: %{},
          total: 0
        })
    end
  end

  def suggest(conn, %{"q" => query}) when byte_size(query) >= 2 do
    # Autocomplete suggestions
    case SearchService.search("#{query}*", 5) do
      {:ok, results} ->
        suggestions =
          results
          |> Enum.map(&extract_suggestion/1)
          |> Enum.uniq()
          |> Enum.take(5)

        json(conn, %{suggestions: suggestions})

      {:error, _} ->
        json(conn, %{suggestions: []})
    end
  end

  def suggest(conn, _params) do
    json(conn, %{suggestions: []})
  end

  def advanced_search(conn, params) do
    query = build_advanced_query(params)

    case SearchService.search(query, 50) do
      {:ok, results} ->
        render(conn, :advanced_search, %{
          results: results,
          params: params,
          query: query
        })

      {:error, reason} ->
        conn
        |> put_flash(:error, "Advanced search failed: #{reason}")
        |> render(:advanced_search, %{results: [], params: params, query: ""})
    end
  end

  # Private functions
  defp validate_search_params(conn, _opts) do
    case get_in(conn.params, ["q"]) do
      query when is_binary(query) and byte_size(query) > 0 ->
        if byte_size(query) <= 1000 do
          conn
        else
          conn
          |> put_flash(:error, "Search query too long")
          |> redirect(to: ~p"/search")
          |> halt()
        end

      _ ->
        conn
        |> put_flash(:error, "Please enter a search query")
        |> redirect(to: ~p"/search")
        |> halt()
    end
  end

  defp parse_limit(%{"limit" => limit}) when is_binary(limit) do
    case Integer.parse(limit) do
      {num, _} when num > 0 and num <= 100 -> num
      _ -> 10
    end
  end
  defp parse_limit(_), do: 10

  defp parse_page(%{"page" => page}) when is_binary(page) do
    case Integer.parse(page) do
      {num, _} when num > 0 -> num
      _ -> 1
    end
  end
  defp parse_page(_), do: 1

  defp paginate_results(results, page, limit) do
    start_index = (page - 1) * limit
    page_results = Enum.slice(results, start_index, limit)

    pagination = %{
      current_page: page,
      per_page: limit,
      total_results: length(results),
      total_pages: div(length(results) + limit - 1, limit)
    }

    {page_results, pagination}
  end

  defp extract_suggestion(result) do
    # Extract meaningful suggestion text
    Map.get(result, "title", "")
  end

  defp build_advanced_query(params) do
    query_parts = []

    query_parts =
      if title = params["title"], do: ["title:(#{title})" | query_parts], else: query_parts

    query_parts =
      if author = params["author"], do: ["author:(#{author})" | query_parts], else: query_parts

    query_parts =
      if category = params["category"], do: ["category:\"#{category}\"" | query_parts], else: query_parts

    query_parts =
      if date_from = params["date_from"] do
        timestamp = parse_date_to_timestamp(date_from)
        ["timestamp:[#{timestamp} TO *]" | query_parts]
      else
        query_parts
      end

    case query_parts do
      [] -> "*"
      parts -> Enum.join(parts, " AND ")
    end
  end

  defp parse_date_to_timestamp(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        date
        |> DateTime.new!(~T[00:00:00])
        |> DateTime.to_unix()

      _ -> 0
    end
  end
end
```

### LiveView Integration

```elixir
defmodule MyAppWeb.SearchLive do
  use MyAppWeb, :live_view
  alias MyApp.SearchService
  require Logger

  @debounce_timeout 300

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:query, "")
      |> assign(:results, [])
      |> assign(:loading, false)
      |> assign(:suggestions, [])
      |> assign(:show_suggestions, false)
      |> assign(:search_stats, %{})

    {:ok, socket}
  end

  def handle_params(%{"q" => query}, _uri, socket) when query != "" do
    send(self(), {:perform_search, query})

    socket =
      socket
      |> assign(:query, query)
      |> assign(:loading, true)
      |> assign(:show_suggestions, false)

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :query, "")}
  end

  def handle_event("search_input", %{"query" => query}, socket) do
    # Cancel any pending search
    if socket.assigns[:search_timer] do
      Process.cancel_timer(socket.assigns.search_timer)
    end

    socket =
      socket
      |> assign(:query, query)
      |> assign(:show_suggestions, String.length(query) >= 2)

    # Set up debounced search
    if String.length(query) >= 2 do
      timer = Process.send_after(self(), {:get_suggestions, query}, @debounce_timeout)
      socket = assign(socket, :search_timer, timer)
      {:noreply, socket}
    else
      socket =
        socket
        |> assign(:suggestions, [])
        |> assign(:show_suggestions, false)
      {:noreply, socket}
    end
  end

  def handle_event("search_submit", %{"query" => query}, socket) do
    if String.trim(query) != "" do
      path = ~p"/search?#{%{q: query}}"
      {:noreply, push_navigate(socket, to: path)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("select_suggestion", %{"suggestion" => suggestion}, socket) do
    path = ~p"/search?#{%{q: suggestion}}"
    {:noreply, push_navigate(socket, to: path)}
  end

  def handle_event("clear_search", _params, socket) do
    socket =
      socket
      |> assign(:query, "")
      |> assign(:results, [])
      |> assign(:suggestions, [])
      |> assign(:show_suggestions, false)
      |> assign(:search_stats, %{})

    {:noreply, push_navigate(socket, to: ~p"/search")}
  end

  def handle_info({:get_suggestions, query}, socket) do
    suggestions = get_search_suggestions(query)

    socket =
      socket
      |> assign(:suggestions, suggestions)
      |> assign(:show_suggestions, length(suggestions) > 0)

    {:noreply, socket}
  end

  def handle_info({:perform_search, query}, socket) do
    start_time = System.monotonic_time(:millisecond)

    results =
      case SearchService.search(query, 20) do
        {:ok, results} -> results
        {:error, reason} ->
          Logger.warning("Search failed: #{inspect(reason)}")
          []
      end

    end_time = System.monotonic_time(:millisecond)
    search_time = end_time - start_time

    stats = %{
      query: query,
      result_count: length(results),
      search_time_ms: search_time
    }

    socket =
      socket
      |> assign(:results, results)
      |> assign(:loading, false)
      |> assign(:search_stats, stats)
      |> assign(:show_suggestions, false)

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="search-container max-w-4xl mx-auto p-6">
      <div class="search-header mb-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-4">Search</h1>

        <div class="relative">
          <form phx-submit="search_submit" class="relative">
            <input
              type="text"
              name="query"
              value={@query}
              placeholder="Search for articles, tutorials, and more..."
              class="w-full px-4 py-3 text-lg border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              phx-keyup="search_input"
              phx-debounce="100"
              autocomplete="off"
            />

            <button
              type="submit"
              class="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
              </svg>
            </button>

            <%= if @query != "" do %>
              <button
                type="button"
                phx-click="clear_search"
                class="absolute right-10 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
              </button>
            <% end %>
          </form>

          <!-- Suggestions dropdown -->
          <%= if @show_suggestions and length(@suggestions) > 0 do %>
            <div class="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg">
              <%= for suggestion <- @suggestions do %>
                <button
                  type="button"
                  phx-click="select_suggestion"
                  phx-value-suggestion={suggestion}
                  class="w-full px-4 py-2 text-left hover:bg-gray-100 first:rounded-t-lg last:rounded-b-lg"
                >
                  <%= suggestion %>
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Search stats -->
      <%= if @search_stats != %{} do %>
        <div class="mb-6 text-sm text-gray-600">
          Found <%= @search_stats.result_count %> results for "<%= @search_stats.query %>"
          in <%= @search_stats.search_time_ms %>ms
        </div>
      <% end %>

      <!-- Loading state -->
      <%= if @loading do %>
        <div class="flex items-center justify-center py-12">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
          <span class="ml-2 text-gray-600">Searching...</span>
        </div>
      <% end %>

      <!-- Results -->
      <%= if not @loading and length(@results) > 0 do %>
        <div class="results space-y-6">
          <%= for result <- @results do %>
            <div class="result-item p-6 bg-white border border-gray-200 rounded-lg shadow-sm hover:shadow-md transition-shadow">
              <h3 class="text-xl font-semibold text-blue-600 mb-2">
                <%= Map.get(result, "title", "Untitled") %>
              </h3>

              <p class="text-gray-700 mb-3">
                <%= Map.get(result, "content", "") |> truncate(200) %>
              </p>

              <div class="flex items-center text-sm text-gray-500 space-x-4">
                <%= if author = Map.get(result, "author") do %>
                  <span>By <%= author %></span>
                <% end %>

                <%= if timestamp = Map.get(result, "timestamp") do %>
                  <span><%= format_timestamp(timestamp) %></span>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- No results -->
      <%= if not @loading and @query != "" and length(@results) == 0 do %>
        <div class="text-center py-12">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 12h6m-6-4h6m2 5.291A7.962 7.962 0 0112 15c-2.34 0-4.469.901-6.062 2.372M9.88 9.88L3.121 3.121A7.966 7.966 0 012 8.5a7.966 7.966 0 011.121 4.121"></path>
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">No results found</h3>
          <p class="mt-1 text-sm text-gray-500">
            Try adjusting your search terms or browse our categories.
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions
  defp get_search_suggestions(query) do
    case SearchService.search("#{query}*", 5) do
      {:ok, results} ->
        results
        |> Enum.map(&Map.get(&1, "title", ""))
        |> Enum.filter(&(&1 != ""))
        |> Enum.uniq()
        |> Enum.take(5)

      {:error, _} -> []
    end
  end

  defp truncate(text, length) when is_binary(text) do
    if String.length(text) <= length do
      text
    else
      String.slice(text, 0, length) <> "..."
    end
  end
  defp truncate(_, _), do: ""

  defp format_timestamp(timestamp) when is_integer(timestamp) do
    case DateTime.from_unix(timestamp) do
      {:ok, datetime} -> Calendar.strftime(datetime, "%B %d, %Y")
      _ -> "Unknown date"
    end
  end
  defp format_timestamp(_), do: "Unknown date"
end
```

## Task-based Indexing

For background indexing operations:

```elixir
defmodule MyApp.IndexingTask do
  use Task, restart: :transient
  require Logger
  alias MyApp.SearchService

  def start_link(documents) when is_list(documents) do
    Task.start_link(__MODULE__, :run, [documents])
  end

  def run(documents) do
    Logger.info("Starting bulk indexing of #{length(documents)} documents")
    start_time = System.monotonic_time(:millisecond)

    try do
      documents
      |> Enum.chunk_every(100)
      |> Enum.with_index()
      |> Enum.each(&process_batch/1)

      SearchService.commit()

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      Logger.info("Bulk indexing completed in #{duration}ms")
      :ok

    rescue
      e ->
        Logger.error("Bulk indexing failed: #{inspect(e)}")
        {:error, e}
    end
  end

  defp process_batch({batch, index}) do
    Logger.debug("Processing batch #{index + 1} with #{length(batch)} documents")

    case SearchService.add_documents(batch) do
      :ok ->
        :ok
      {:error, reason} ->
        Logger.warning("Batch #{index + 1} failed: #{inspect(reason)}")
        raise "Batch processing failed: #{reason}"
    end

    # Brief pause to prevent overwhelming the system
    if rem(index, 10) == 0 do
      Process.sleep(100)
    end
  end
end

# Usage
defmodule MyApp.DataIndexer do
  def reindex_all do
    documents = fetch_all_documents_from_database()

    # Start background indexing task
    {:ok, task} = MyApp.IndexingTask.start_link(documents)

    # Optional: Monitor the task
    ref = Process.monitor(task)

    receive do
      {:DOWN, ^ref, :process, ^task, :normal} ->
        Logger.info("Indexing completed successfully")
        :ok

      {:DOWN, ^ref, :process, ^task, reason} ->
        Logger.error("Indexing task failed: #{inspect(reason)}")
        {:error, reason}
    after
      300_000 -> # 5 minute timeout
        Process.exit(task, :timeout)
        {:error, :timeout}
    end
  end

  defp fetch_all_documents_from_database do
    # Your database query logic here
    []
  end
end
```

## Supervision Strategies

Integrate TantivyEx services into your supervision tree:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Database
      MyApp.Repo,

      # Search services
      MyApp.SearchService,

      # Web endpoint
      MyAppWeb.Endpoint,

      # Background tasks
      {Task.Supervisor, name: MyApp.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

These integration patterns provide a solid foundation for building search functionality into your Elixir applications with proper error handling, performance considerations, and user experience optimizations.
