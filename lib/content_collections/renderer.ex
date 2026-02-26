defmodule ContentCollections.Renderer do
  @moduledoc """
  Behavior for content renderers.

  A renderer is responsible for converting content (typically markdown)
  into HTML or other output formats.

  ## Implementing a Renderer

      defmodule MyApp.CustomRenderer do
        @behaviour ContentCollections.Renderer

        @impl true
        def render(content, opts) do
          # Convert content to HTML
          html = MyMarkdownLibrary.to_html(content, opts)
          {:ok, html}
        end
      end

  ## Options

  Renderers can accept various options to customize output:

  - `:sanitize` - Whether to sanitize HTML output
  - `:syntax_highlight` - Enable syntax highlighting for code blocks
  - Extension options specific to the markdown processor
  """

  @doc """
  Renders content to HTML.

  Takes raw content (usually markdown) and returns rendered HTML.

  ## Options

  Options are renderer-specific. Common options include:

  - `:extension` - Map of extension flags for the markdown processor
  - `:sanitize` - Whether to sanitize the output HTML
  - `:syntax_highlight` - Whether to highlight code blocks
  """
  @callback render(content :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}

  @doc """
  Normalizes renderer specification into a module and options tuple.
  """
  @spec normalize(renderer :: module() | {module(), keyword()} | nil) :: {module(), keyword()}
  def normalize(nil), do: {ContentCollections.Renderers.MDEx, []}
  def normalize(renderer) when is_atom(renderer), do: {renderer, []}
  def normalize({renderer, opts}) when is_atom(renderer) and is_list(opts), do: {renderer, opts}

  def normalize(other) do
    raise ArgumentError, """
    Invalid renderer specification: #{inspect(other)}

    Expected a module or {module, options} tuple.
    """
  end
end
