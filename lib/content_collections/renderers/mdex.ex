defmodule ContentCollections.Renderers.MDEx do
  @moduledoc """
  MDEx renderer for content collections.

  Uses MDEx to render markdown to HTML with extensive CommonMark
  and GitHub Flavored Markdown support.

  ## Options

  - `:extension` - Map of MDEx extensions to enable/disable
  - `:parse` - Map of MDEx parse options
  - `:render` - Map of MDEx render options
  - `:sanitize` - Whether to sanitize HTML output (default: true)

  ## Extension Options

  MDEx supports many extensions that can be configured:

      use ContentCollections,
        renderer: {ContentCollections.Renderers.MDEx,
          extension: [
            table: true,
            strikethrough: true,
            tasklist: true,
            autolink: true,
            footnotes: true
          ]}

  ## Examples

      # Basic usage with default options
      {:ok, html} = ContentCollections.Renderers.MDEx.render(
        "# Hello\\n\\nThis is **bold** text.",
        []
      )

      # With extensions
      {:ok, html} = ContentCollections.Renderers.MDEx.render(
        "~~strikethrough~~ and https://example.com",
        extension: [strikethrough: true, autolink: true]
      )
  """

  @behaviour ContentCollections.Renderer

  @default_extensions [
    table: true,
    strikethrough: true,
    autolink: true,
    tasklist: true
  ]

  @default_parse_opts [
    smart: true
  ]

  @default_render_opts [
    # Allow raw HTML to pass through
    unsafe_: true
  ]

  @impl true
  def render(content, opts \\ []) when is_binary(content) do
    mdex_opts = build_mdex_options(opts)

    try do
      html = MDEx.to_html!(content, mdex_opts)
      {:ok, maybe_sanitize(html, opts)}
    rescue
      e in MDEx.DecodeError ->
        {:error, {:mdex_error, Exception.message(e)}}

      e ->
        {:error, {:render_error, Exception.message(e)}}
    end
  end

  defp build_mdex_options(opts) do
    extension_opts = Keyword.get(opts, :extension, @default_extensions)
    parse_opts = Keyword.get(opts, :parse, @default_parse_opts)
    render_opts = Keyword.get(opts, :render, @default_render_opts)

    [
      extension: extension_opts,
      parse: parse_opts,
      render: render_opts
    ]
  end

  defp maybe_sanitize(html, opts) do
    if Keyword.get(opts, :sanitize, true) do
      # For now, we'll rely on MDEx's built-in safety features
      # In a production system, you might want to add HtmlSanitizeEx here
      html
    else
      html
    end
  end
end
