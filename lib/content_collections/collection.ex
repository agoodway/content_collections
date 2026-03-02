defmodule ContentCollections.Collection do
  @moduledoc """
  Defines a content collection with compile-time or runtime loading.

  This module provides a macro to define content collections that can
  load content either at compile time (for production performance) or
  at runtime (for development flexibility).

  ## Usage

      defmodule MyApp.Blog do
        use ContentCollections.Collection,
          name: :blog,
          loader: {ContentCollections.Loaders.Filesystem,
            path: "content/blog/**/*.md"},
          compile_time: Mix.env() == :prod
      end

  ## Options

  - `:name` - The collection name (defaults to module name)
  - `:loader` - A tuple of `{loader_module, opts}` (required)
  - `:compile_time` - Whether to load at compile time (default: true in prod)
  - `:renderer` - A tuple of `{renderer_module, opts}`
  - `:parser` - A tuple of `{parser_module, opts}`
  - `:schema` - Schema definition for validation
  - `:cache` - Enable runtime caching (default: true for runtime loading)
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour ContentCollections.Collection

      # Store configuration
      @collection_opts opts
      @collection_name Keyword.get(opts, :name, __MODULE__)
      @compile_time Keyword.get(opts, :compile_time, Mix.env() == :prod)
      @cache_enabled Keyword.get(opts, :cache, true)
      @loader ContentCollections.Loader.normalize(Keyword.fetch!(opts, :loader))
      @renderer ContentCollections.Renderer.normalize(Keyword.get(opts, :renderer))

      # Validate loader configuration at compile time
      {loader_module, loader_opts} = @loader

      case ContentCollections.Loader.validate_opts(loader_module, loader_opts) do
        :ok -> :ok
        {:error, message} -> raise "Invalid loader configuration: #{message}"
      end

      if @compile_time do
        # Load content at compile time
        @external_resource Path.expand(elem(@loader, 1)[:path] || ".", __DIR__)

        entries =
          ContentCollections.Collection.load_and_transform_entries(
            elem(@loader, 0),
            elem(@loader, 1),
            __MODULE__
          )

        @entries entries
        @entries_by_id Map.new(entries, fn entry -> {entry.id, entry} end)
        @entries_by_slug Map.new(entries, fn entry -> {entry.slug, entry} end)

        def __compile_time__, do: true
        def __entries__, do: @entries
        def __cache_enabled__, do: false
        def __cache_key__, do: {ContentCollections.Collection, __MODULE__, :entries}

        defp load_entries, do: @entries
        defp get_compile_time_by_id(id), do: Map.get(@entries_by_id, id)
        defp get_compile_time_by_slug(slug), do: Map.get(@entries_by_slug, slug)
      else
        def __compile_time__, do: false
        def __entries__, do: get_runtime_entries()
        def __cache_enabled__, do: @cache_enabled
        def __cache_key__, do: {ContentCollections.Collection, __MODULE__, :entries}

        defp load_entries do
          {loader_module, loader_opts} = @loader

          ContentCollections.Collection.load_and_transform_entries(
            loader_module,
            loader_opts,
            __MODULE__
          )
        end

        defp get_runtime_entries do
          if __cache_enabled__() do
            load_or_get_cached()
          else
            load_entries()
          end
        end

        defp load_or_get_cached do
          cache_key = __cache_key__()

          case :persistent_term.get(cache_key, :not_loaded) do
            :not_loaded ->
              entries = load_entries()
              :persistent_term.put(cache_key, entries)
              entries

            entries ->
              entries
          end
        end

        defp get_compile_time_by_id(_id), do: nil
        defp get_compile_time_by_slug(_slug), do: nil
      end

      ContentCollections.Collection.__define_finders__()
      ContentCollections.Collection.__define_filters__()
      ContentCollections.Collection.__define_lifecycle__()
    end
  end

  @doc false
  defmacro __define_finders__ do
    quote do
      def __collection_name__, do: @collection_name
      def __loader__, do: @loader
      def __renderer__, do: @renderer

      @impl true
      def all do
        __entries__()
      end

      @impl true
      def get(id) when is_binary(id) do
        if __compile_time__() do
          get_compile_time_by_id(id)
        else
          Enum.find(all(), fn entry -> entry.id == id end)
        end
      end

      @impl true
      def get_by_slug(slug) when is_binary(slug) do
        if __compile_time__() do
          get_compile_time_by_slug(slug)
        else
          Enum.find(all(), fn entry -> entry.slug == slug end)
        end
      end
    end
  end

  @doc false
  defmacro __define_filters__ do
    quote do
      @impl true
      def filter(fun) when is_function(fun, 1) do
        all()
        |> Enum.filter(fun)
      end

      @impl true
      def filter(fun, opts) when is_function(fun, 1) and is_list(opts) do
        all()
        |> Enum.filter(fun)
        |> ContentCollections.Collection.paginate_entries(opts)
      end

      @impl true
      def find(fun) when is_function(fun, 1) do
        all()
        |> Enum.find(fun)
      end

      @impl true
      def count do
        length(all())
      end

      @impl true
      def exists?(id) when is_binary(id) do
        get(id) != nil
      end
    end
  end

  @doc false
  defmacro __define_lifecycle__ do
    quote do
      @impl true
      def paginate(opts \\ []) when is_list(opts) do
        all()
        |> ContentCollections.Collection.paginate_entries(opts)
      end

      @impl true
      def reload do
        if __compile_time__() do
          {:error, :compile_time_collection}
        else
          reload_runtime_entries()
        end
      end

      defp reload_runtime_entries do
        if __cache_enabled__() do
          cache_key = __cache_key__()
          :persistent_term.erase(cache_key)
          entries = __entries__()
          {:ok, entries}
        else
          {:ok, load_entries()}
        end
      end

      # Allow collections to be extended
      defoverridable all: 0, get: 1, get_by_slug: 1, filter: 1, filter: 2, paginate: 1
    end
  end

  @doc """
  Returns all entries in the collection.
  """
  @callback all() :: [ContentCollections.Entry.t()]

  @doc """
  Gets an entry by ID.
  """
  @callback get(id :: String.t()) :: ContentCollections.Entry.t() | nil

  @doc """
  Gets an entry by slug.
  """
  @callback get_by_slug(slug :: String.t()) :: ContentCollections.Entry.t() | nil

  @doc """
  Filters entries by a function.
  """
  @callback filter(fun :: (ContentCollections.Entry.t() -> boolean())) :: [
              ContentCollections.Entry.t()
            ]

  @doc """
  Filters entries by a function and paginates the results.
  """
  @callback filter(
              fun :: (ContentCollections.Entry.t() -> boolean()),
              opts :: keyword()
            ) :: {[ContentCollections.Entry.t()], map()}

  @doc """
  Paginates all entries.
  """
  @callback paginate(opts :: keyword()) :: {[ContentCollections.Entry.t()], map()}

  @doc """
  Finds the first entry matching a function.
  """
  @callback find(fun :: (ContentCollections.Entry.t() -> boolean())) ::
              ContentCollections.Entry.t() | nil

  @doc """
  Returns the count of entries.
  """
  @callback count() :: non_neg_integer()

  @doc """
  Checks if an entry exists by ID.
  """
  @callback exists?(id :: String.t()) :: boolean()

  @doc """
  Reloads the collection (only works for runtime collections).
  """
  @callback reload() ::
              {:ok, [ContentCollections.Entry.t()]} | {:error, :compile_time_collection}

  @doc false
  def paginate_entries(entries, opts) do
    %{page: page, per_page: per_page} = normalize_pagination_opts(opts)
    total_entries = length(entries)

    total_pages =
      if total_entries == 0, do: 0, else: div(total_entries + per_page - 1, per_page)

    offset = (page - 1) * per_page

    page_entries =
      entries
      |> Enum.drop(offset)
      |> Enum.take(per_page)

    {page_entries, build_pagination_meta(page, per_page, total_entries, total_pages)}
  end

  defp build_pagination_meta(page, per_page, total_entries, total_pages) do
    %{
      page: page,
      per_page: per_page,
      total_entries: total_entries,
      total_pages: total_pages,
      has_prev_page: page > 1 and total_pages > 0,
      has_next_page: page < total_pages
    }
  end

  defp normalize_pagination_opts(opts) do
    %{
      page: normalize_positive_integer(Keyword.get(opts, :page, 1), 1),
      per_page: normalize_positive_integer(Keyword.get(opts, :per_page, 20), 20)
    }
  end

  defp normalize_positive_integer(value, _default) when is_integer(value) and value > 0,
    do: value

  defp normalize_positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> integer
      _ -> default
    end
  end

  defp normalize_positive_integer(_value, default), do: default

  # Helper function to load and transform entries
  def load_and_transform_entries(loader_module, loader_opts, collection_module) do
    case loader_module.load(loader_opts) do
      {:ok, entries} ->
        Enum.map(entries, fn entry_data ->
          entry_data
          |> Map.put(:collection, collection_module)
          |> Map.to_list()
          |> ContentCollections.Entry.new()
        end)

      {:error, reason} ->
        raise "Failed to load content: #{inspect(reason)}"
    end
  end
end
