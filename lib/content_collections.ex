defmodule ContentCollections do
  @moduledoc """
  A content collections library for Elixir, inspired by Astro's content collections.

  ContentCollections provides a flexible system for managing markdown content with
  frontmatter, supporting both compile-time and runtime loading strategies.

  ## Features

  - **Flexible Loading**: Support for compile-time and runtime content loading
  - **Multiple Sources**: Built-in filesystem loader with behavior for custom loaders
  - **Schema Validation**: Validate frontmatter with Ecto-like schemas
  - **Markdown Rendering**: MDEx integration for CommonMark compliant rendering
  - **Extensible**: Pluggable loaders, renderers, and parsers

  ## Installation

  Add to your dependencies:

      {:content_collections, "~> 0.1.0"}

  ## Basic Usage

      defmodule MyApp.Blog do
        use ContentCollections,
          loader: {ContentCollections.Loaders.Filesystem,
            path: "priv/content/blog/**/*.md"},
          compile_time: Mix.env() == :prod
      end

      # Query your content
      MyApp.Blog.all()
      MyApp.Blog.get("my-post")
      MyApp.Blog.filter(&(&1.metadata.published))

  ## Configuration Options

  - `:loader` - A tuple of `{loader_module, opts}` specifying how to load content
  - `:compile_time` - Boolean indicating whether to load at compile time (default: `true` in prod)
  - `:renderer` - A tuple of `{renderer_module, opts}` for markdown rendering
  - `:parser` - A tuple of `{parser_module, opts}` for frontmatter parsing
  - `:schema` - A schema definition for validating frontmatter

  ## Advanced Usage

  ### Custom Loaders

      defmodule MyApp.APILoader do
        @behaviour ContentCollections.Loader

        @impl true
        def load(opts) do
          # Fetch content from API
          {:ok, entries}
        end
      end

      defmodule MyApp.Posts do
        use ContentCollections,
          loader: {MyApp.APILoader, endpoint: "/api/posts"}
      end

  ### Schema Validation

      defmodule MyApp.Articles do
        use ContentCollections,
          loader: {ContentCollections.Loaders.Filesystem,
            path: "content/articles/**/*.md"},
          schema: %{
            title: :string,
            date: :date,
            author: :string,
            tags: {:array, :string},
            published: {:boolean, default: false}
          }
      end

  ### Custom Rendering

      defmodule MyApp.Docs do
        use ContentCollections,
          loader: {ContentCollections.Loaders.Filesystem,
            path: "docs/**/*.md"},
          renderer: {ContentCollections.Renderers.MDEx,
            extension: [
              table: true,
              strikethrough: true,
              tasklist: true
            ]}
      end

  ### Phoenix Components in Markdown

  ContentCollections supports embedding Phoenix components directly in markdown:

      defmodule MyApp.Blog do
        use ContentCollections,
          loader: {ContentCollections.Loaders.Filesystem,
            path: "content/**/*.md"},
          renderer: {ContentCollections.Renderers.PhoenixComponent,
            components: %{
              weather: MyApp.WeatherComponent,
              chart: MyApp.ChartComponent
            }}
      end

  In your markdown files, you can embed components using two syntaxes:

      ---
      title: Weather Report
      city: Phoenix
      temp_unit: F
      ---

      # Weather in {@city}

      ## Shortcode syntax:
      {:weather city: @city, unit: @temp_unit}

      ## HTML-like syntax:
      <Weather city={@city} unit={@temp_unit} />

  Frontmatter values are available as assigns in components.
  """

  @doc """
  Use this module to define a content collection.

  See module documentation for configuration options.
  """
  defmacro __using__(opts) do
    quote do
      use ContentCollections.Collection, unquote(opts)
    end
  end
end
