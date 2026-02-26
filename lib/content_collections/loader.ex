defmodule ContentCollections.Loader do
  @moduledoc """
  Behavior for content loaders.

  A loader is responsible for fetching content from a source and returning
  a list of entries. Loaders can fetch from filesystem, APIs, databases, or
  any other source.

  ## Implementing a Loader

      defmodule MyApp.CustomLoader do
        @behaviour ContentCollections.Loader

        @impl true
        def load(opts) do
          # Fetch content based on opts
          entries = fetch_entries(opts[:source])

          {:ok, entries}
        end
      end

  ## Entry Format

  Loaders should return entries as maps with the following keys:

  - `:id` - Unique identifier (required)
  - `:slug` - URL-friendly identifier (optional, can be derived from id)
  - `:content` - Raw content (required)
  - `:metadata` - Map of frontmatter/metadata (optional)

  ## Example Entry

      %{
        id: "2024-01-15-hello-world",
        slug: "hello-world",
        content: "# Hello World\\n\\nThis is my first post.",
        metadata: %{
          title: "Hello World",
          date: ~D[2024-01-15],
          tags: ["introduction", "meta"]
        }
      }
  """

  @doc """
  Loads content from the configured source.

  Returns a list of entry maps on success, or an error tuple.

  ## Options

  Options are loader-specific. Common options include:

  - `:path` - For filesystem loaders
  - `:url` - For HTTP loaders
  - `:query` - For database loaders
  """
  @callback load(opts :: keyword()) :: {:ok, [map()]} | {:error, term()}

  @doc """
  Optional callback to validate loader options at compile time.

  If implemented, this will be called when the collection is defined
  to catch configuration errors early.
  """
  @callback validate_opts(opts :: keyword()) :: :ok | {:error, String.t()}

  @optional_callbacks validate_opts: 1

  @doc """
  Normalizes loader specification into a module and options tuple.
  """
  @spec normalize(loader :: module() | {module(), keyword()}) :: {module(), keyword()}
  def normalize(loader) when is_atom(loader), do: {loader, []}
  def normalize({loader, opts}) when is_atom(loader) and is_list(opts), do: {loader, opts}

  def normalize(other) do
    raise ArgumentError, """
    Invalid loader specification: #{inspect(other)}

    Expected a module or {module, options} tuple.
    """
  end

  @doc """
  Validates loader options if the loader implements validate_opts/1.
  """
  @spec validate_opts(module(), keyword()) :: :ok | {:error, String.t()}
  def validate_opts(loader_module, opts) do
    if function_exported?(loader_module, :validate_opts, 1) do
      loader_module.validate_opts(opts)
    else
      :ok
    end
  end
end
