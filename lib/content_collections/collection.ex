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

        defp load_entries do
          @entries
        end
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
            cache_key = __cache_key__()

            case :persistent_term.get(cache_key, :not_loaded) do
              :not_loaded ->
                entries = load_entries()
                :persistent_term.put(cache_key, entries)
                entries

              entries ->
                entries
            end
          else
            load_entries()
          end
        end
      end

      def __collection_name__, do: @collection_name
      def __loader__, do: @loader
      def __renderer__, do: @renderer

      # Query functions

      @impl true
      def all do
        if __compile_time__() do
          __entries__()
        else
          __entries__()
        end
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

      if @compile_time do
        defp get_compile_time_by_id(id), do: Map.get(@entries_by_id, id)
        defp get_compile_time_by_slug(slug), do: Map.get(@entries_by_slug, slug)
      else
        defp get_compile_time_by_id(_id), do: nil
        defp get_compile_time_by_slug(_slug), do: nil
      end

      @impl true
      def filter(fun) when is_function(fun, 1) do
        all()
        |> Enum.filter(fun)
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

      @impl true
      def reload do
        if __compile_time__() do
          {:error, :compile_time_collection}
        else
          if __cache_enabled__() do
            cache_key = __cache_key__()
            :persistent_term.erase(cache_key)
            entries = __entries__()
            {:ok, entries}
          else
            {:ok, load_entries()}
          end
        end
      end

      # Allow collections to be extended
      defoverridable all: 0, get: 1, get_by_slug: 1, filter: 1
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
