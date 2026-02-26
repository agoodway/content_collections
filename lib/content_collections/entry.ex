defmodule ContentCollections.Entry do
  @moduledoc """
  Represents a single content entry in a collection.

  An entry contains metadata from frontmatter, the raw content,
  and can render to HTML on demand.
  """

  @enforce_keys [:id, :slug, :content]
  defstruct [:id, :slug, :metadata, :content, :html, :collection]

  @type t :: %__MODULE__{
          id: String.t(),
          slug: String.t(),
          metadata: map(),
          content: String.t(),
          html: String.t() | nil,
          collection: atom()
        }

  @doc """
  Creates a new content entry.

  ## Options

  - `:id` - Unique identifier for the entry (required)
  - `:slug` - URL-friendly identifier (required)
  - `:content` - Raw markdown content (required)
  - `:metadata` - Frontmatter data as a map
  - `:collection` - The collection this entry belongs to
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    struct!(__MODULE__, opts)
  end

  @doc """
  Renders the entry's content to HTML.

  Uses the collection's configured renderer or falls back to the default.
  The rendered HTML is cached in the entry struct.

  ## Options

  - `:force` - Force re-rendering even if HTML is already cached
  - `:renderer` - Override the default renderer
  """
  @spec render(t(), keyword()) :: {:ok, t()} | {:error, term()}
  def render(%__MODULE__{html: html} = entry, opts \\ []) when is_list(opts) do
    if html && !Keyword.get(opts, :force, false) do
      {:ok, entry}
    else
      do_render(entry, opts)
    end
  end

  defp do_render(%__MODULE__{content: content} = entry, opts) do
    {renderer_module, renderer_opts} = get_renderer(entry, opts)

    case renderer_module.render(content, renderer_opts) do
      {:ok, html} ->
        {:ok, %{entry | html: html}}

      {:error, _reason} = error ->
        error
    end
  end

  defp get_renderer(entry, opts) do
    Keyword.get_lazy(opts, :renderer, fn ->
      if entry.collection && function_exported?(entry.collection, :__renderer__, 0) do
        entry.collection.__renderer__()
      else
        {ContentCollections.Renderers.MDEx, []}
      end
    end)
    |> normalize_renderer()
  end

  defp normalize_renderer({module, opts}), do: {module, opts}
  defp normalize_renderer(module) when is_atom(module), do: {module, []}

  @doc """
  Renders the entry's content to HTML, raising on error.
  """
  @spec render!(t(), keyword()) :: t()
  def render!(entry, opts \\ []) do
    case render(entry, opts) do
      {:ok, entry} -> entry
      {:error, reason} -> raise "Failed to render entry: #{inspect(reason)}"
    end
  end

  @doc """
  Returns the entry's HTML, rendering if necessary.
  """
  @spec to_html(t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def to_html(entry, opts \\ []) do
    case render(entry, opts) do
      {:ok, %{html: html}} -> {:ok, html}
      error -> error
    end
  end

  @doc """
  Returns the entry's HTML, rendering if necessary. Raises on error.
  """
  @spec to_html!(t(), keyword()) :: String.t()
  def to_html!(entry, opts \\ []) do
    case to_html(entry, opts) do
      {:ok, html} -> html
      {:error, reason} -> raise "Failed to render entry: #{inspect(reason)}"
    end
  end

  @doc """
  Renders the entry's content to HTML with Phoenix component support.

  This function allows embedding Phoenix components in markdown content.
  The entry's metadata is available as assigns in the components.

  ## Options

  - `:force` - Force re-rendering even if HTML is already cached
  - `:renderer` - Must be PhoenixComponent renderer or compatible
  - `:components` - Map of component name to module
  - `:extra_assigns` - Additional assigns to merge with metadata

  ## Examples

      {:ok, rendered} = Entry.render_with_components(entry,
        components: %{weather: MyApp.WeatherComponent},
        extra_assigns: %{user: current_user}
      )
  """
  @spec render_with_components(t(), keyword()) :: {:ok, t()} | {:error, term()}
  def render_with_components(%__MODULE__{} = entry, opts \\ []) when is_list(opts) do
    # Prepare assigns from metadata and extra assigns
    metadata_assigns = prepare_metadata_assigns(entry.metadata)
    extra_assigns = Keyword.get(opts, :extra_assigns, %{})
    assigns = Map.merge(metadata_assigns, normalize_assigns(extra_assigns))

    # Get the renderer and merge options
    {renderer_module, renderer_opts} =
      case Keyword.get(opts, :renderer) do
        {mod, ropts} when is_list(ropts) ->
          # Merge assigns into existing renderer options
          {mod, Keyword.put(ropts, :assigns, assigns)}

        {mod, ropts} when is_map(ropts) ->
          # Convert map to keyword list and add assigns
          {mod, Map.to_list(ropts) ++ [assigns: assigns]}

        nil ->
          # Default to PhoenixComponent renderer with options from opts
          {ContentCollections.Renderers.PhoenixComponent, Keyword.merge(opts, assigns: assigns)}
      end

    # Render with the configured renderer
    render(entry, renderer: {renderer_module, renderer_opts})
  end

  @doc """
  Renders the entry's content to HTML with Phoenix components, raising on error.
  """
  @spec render_with_components!(t(), keyword()) :: t()
  def render_with_components!(entry, opts \\ []) do
    case render_with_components(entry, opts) do
      {:ok, entry} -> entry
      {:error, reason} -> raise "Failed to render entry with components: #{inspect(reason)}"
    end
  end

  defp prepare_metadata_assigns(nil), do: %{}

  defp prepare_metadata_assigns(metadata) when is_map(metadata) do
    # Convert metadata to assigns format
    # Atom keys are preserved, string keys are converted to atoms
    metadata
    |> Enum.map(fn
      {key, value} when is_atom(key) -> {key, value}
      {key, value} when is_binary(key) -> {String.to_atom(key), value}
    end)
    |> Map.new()
  end

  defp normalize_assigns(assigns) when is_map(assigns), do: assigns
  defp normalize_assigns(assigns) when is_list(assigns), do: Map.new(assigns)
  defp normalize_assigns(_), do: %{}

  @doc """
  Extracts a slug from a file path.

  ## Examples

      iex> ContentCollections.Entry.slug_from_path("content/blog/hello-world.md")
      "hello-world"

      iex> ContentCollections.Entry.slug_from_path("posts/2024/01/new-year.md")
      "new-year"
  """
  @spec slug_from_path(String.t()) :: String.t()
  def slug_from_path(path) do
    path
    |> Path.basename()
    |> Path.rootname()
  end
end
