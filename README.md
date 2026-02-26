# ContentCollections

A content management library for Elixir, inspired by Astro's content collections. Define typed, queryable collections of markdown content with YAML frontmatter — loaded at compile time for production performance or at runtime for development flexibility.

## Features

- **Compile-time loading** — content is embedded into your application at build time, with zero filesystem overhead in production
- **Runtime loading** — reload content without recompiling, ideal for development and CMS-backed workflows
- **Filesystem loader** — glob-pattern file discovery with automatic frontmatter parsing
- **CommonMark rendering** — MDEx (Rust-based) renderer with GFM extensions enabled by default
- **Phoenix component embedding** — embed whitelisted function components directly in markdown using shortcode or HTML-like syntax
- **Pluggable architecture** — custom loaders, parsers, and renderers via well-defined behaviours

## Installation

Add `content_collections` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:content_collections, "~> 0.1.0"}
  ]
end
```

For Phoenix component support in markdown, also add:

```elixir
{:phoenix_live_view, "~> 1.1"},
{:phoenix_html, "~> 4.1"}
```

## Quick Start

Define a collection module and point it at your content directory:

```elixir
defmodule MyApp.Blog do
  use ContentCollections,
    loader: {ContentCollections.Loaders.Filesystem,
      path: "priv/content/blog/**/*.md"},
    compile_time: Mix.env() == :prod
end
```

Query and render entries anywhere in your application:

```elixir
# List all posts
posts = MyApp.Blog.all()

# Get a specific post by slug
post = MyApp.Blog.get_by_slug("building-phoenix-apps")

# Render markdown to HTML
{:ok, rendered} = ContentCollections.Entry.render(post)
rendered.html
```

## Content Format

Each markdown file should include a YAML frontmatter block delimited by `---`:

```markdown
---
title: Building Phoenix Apps with Elixir
date: 2024-03-15
author: Jane Doe
tags:
  - elixir
  - phoenix
published: true
draft: false
---

# Building Phoenix Apps with Elixir

Your content goes here. Standard CommonMark markdown is supported,
including **bold**, *italic*, `code`, and [links](https://example.com).

## Code Blocks

    defmodule Hello do
      def greet(name), do: "Hello, #{name}!"
    end
```

Files without frontmatter are supported — the parser returns an empty metadata map and treats the entire file as body content.

### Normalized Metadata Fields

The Filesystem loader normalizes these common frontmatter keys to atom keys with typed values:

| Frontmatter key | Elixir key   | Type                                   |
|-----------------|--------------|----------------------------------------|
| `title`         | `:title`     | `String.t()`                           |
| `date`          | `:date`      | `Date.t()` (parsed from ISO 8601)      |
| `tags`          | `:tags`      | `[String.t()]`                         |
| `published`     | `:published` | `boolean()`                            |
| `draft`         | `:draft`     | `boolean()`                            |

All other string keys are converted to atom keys. Values for non-normalized keys are preserved as-is.

## Configuration

All options are passed to `use ContentCollections` (or `use ContentCollections.Collection`):

### `:loader` (required)

Specifies how content is loaded. Accepts a `{module, opts}` tuple or a bare module.

```elixir
loader: {ContentCollections.Loaders.Filesystem, path: "priv/content/**/*.md"}
```

### `:compile_time`

Controls when content is loaded. Defaults to `true` when `Mix.env() == :prod`.

```elixir
compile_time: Mix.env() == :prod
```

When `true`, content is loaded once at compile time and stored as module attributes. When `false`, content is loaded at runtime (cached after first access by default).

### `:name`

An atom name for the collection. Defaults to the module name.

```elixir
name: :blog
```

### `:renderer`

Specifies the renderer used when calling `Entry.render/2`. Defaults to `{ContentCollections.Renderers.MDEx, []}`.

```elixir
renderer: {ContentCollections.Renderers.MDEx,
  extension: [table: true, strikethrough: true, footnotes: true]}
```

### Filesystem loader `:parser`

For the filesystem loader, you can override frontmatter parsing by passing `:parser` in the loader opts. Defaults to `ContentCollections.Parsers.YAML`.

```elixir
loader: {ContentCollections.Loaders.Filesystem,
  path: "priv/content/**/*.md",
  parser: MyApp.TOMLParser}
```

### `:schema`

Accepted for compatibility, but not currently enforced by the library.

```elixir
schema: %{
  title: :string,
  date: :date,
  author: :string,
  tags: {:array, :string},
  published: {:boolean, default: false}
}
```

### `:cache`

Enables runtime caching for collections with `compile_time: false`. Defaults to `true` for runtime collections.

When enabled, entries are loaded once on first access and cached in memory. `reload/0` clears and repopulates the cache.

When disabled, entries are loaded from the loader on every query call.

```elixir
cache: true
```

## Querying Content

All query functions are defined on the collection module.

### `all/0`

Returns all entries in the collection.

```elixir
posts = MyApp.Blog.all()
# => [%ContentCollections.Entry{}, ...]
```

### `get/1`

Finds an entry by its ID. The ID defaults to the relative file path, or the `id` field from frontmatter if present. Returns `nil` if not found.

```elixir
entry = MyApp.Blog.get("priv/content/blog/hello-world.md")
```

### `get_by_slug/1`

Finds an entry by slug. The slug is derived from the filename without extension (e.g., `hello-world.md` becomes `"hello-world"`). Returns `nil` if not found.

```elixir
entry = MyApp.Blog.get_by_slug("hello-world")
```

### `filter/1`

Returns all entries matching a predicate function.

```elixir
# Published posts only
published = MyApp.Blog.filter(& &1.metadata.published)

# Posts with a specific tag
elixir_posts = MyApp.Blog.filter(fn entry ->
  "elixir" in (entry.metadata[:tags] || [])
end)

# Posts from 2024
posts_2024 = MyApp.Blog.filter(fn entry ->
  entry.metadata[:date] && entry.metadata.date.year == 2024
end)
```

### `find/1`

Returns the first entry matching a predicate, or `nil`.

```elixir
featured = MyApp.Blog.find(& &1.metadata[:featured])
```

### `count/0`

Returns the total number of entries.

```elixir
total = MyApp.Blog.count()
# => 42
```

### `exists?/1`

Returns `true` if an entry with the given ID exists.

```elixir
if MyApp.Blog.exists?("priv/content/blog/hello-world.md") do
  # ...
end
```

### `reload/0`

Reloads content from the source. Only available for runtime collections — returns `{:error, :compile_time_collection}` for compile-time collections.

```elixir
{:ok, entries} = MyApp.Blog.reload()
```

## Rendering

Entries hold raw markdown in the `:content` field. Rendering to HTML is done on demand and cached in the `:html` field.

### `Entry.render/2`

Renders the entry and returns `{:ok, updated_entry}` with `:html` populated. Skips rendering if HTML is already cached in the entry struct.

```elixir
{:ok, entry} = ContentCollections.Entry.render(post)
entry.html
# => "<h1>Hello World</h1>\n<p>Content here...</p>"
```

Options:

| Option       | Description                                                            |
|--------------|------------------------------------------------------------------------|
| `:force`     | Re-render even if HTML is already cached (default: `false`)            |
| `:renderer`  | Override the collection's configured renderer for this call            |

```elixir
# Force re-render with a different renderer
{:ok, entry} = ContentCollections.Entry.render(post,
  force: true,
  renderer: {ContentCollections.Renderers.MDEx, extension: [footnotes: true]}
)
```

### `Entry.render!/2`

Same as `render/2` but raises on error instead of returning an error tuple.

```elixir
entry = ContentCollections.Entry.render!(post)
```

### `Entry.to_html/2` and `Entry.to_html!/2`

Convenience functions that return the HTML string directly rather than the full entry struct.

```elixir
{:ok, html} = ContentCollections.Entry.to_html(post)

# Raising variant
html = ContentCollections.Entry.to_html!(post)
```

### MDEx Renderer Options

The default renderer, `ContentCollections.Renderers.MDEx`, wraps the MDEx library. The following extensions are enabled by default:

| Extension       | Default |
|-----------------|---------|
| `table`         | `true`  |
| `strikethrough` | `true`  |
| `autolink`      | `true`  |
| `tasklist`      | `true`  |

Configure extensions on the collection:

```elixir
defmodule MyApp.Docs do
  use ContentCollections,
    loader: {ContentCollections.Loaders.Filesystem, path: "priv/docs/**/*.md"},
    renderer: {ContentCollections.Renderers.MDEx,
      extension: [
        table: true,
        strikethrough: true,
        autolink: true,
        tasklist: true,
        footnotes: true
      ],
      parse: [smart: true],
      render: [unsafe_: true]
    }
end
```

Available renderer options:

| Option       | Description                                        |
|--------------|----------------------------------------------------|
| `:extension` | Keyword list of MDEx extension flags               |
| `:parse`     | Keyword list of MDEx parse options                 |
| `:render`    | Keyword list of MDEx render options                |
| `:sanitize`  | Reserved option; currently does not alter output    |

## Phoenix Components in Markdown

`ContentCollections.Renderers.PhoenixComponent` extends the MDEx renderer to support embedded Phoenix function components. Components are resolved at render time from a whitelist you configure.

### Setup

```elixir
defmodule MyApp.Blog do
  use ContentCollections,
    loader: {ContentCollections.Loaders.Filesystem, path: "priv/content/**/*.md"},
    renderer: {ContentCollections.Renderers.PhoenixComponent,
      components: %{
        callout: MyApp.Components.Callout,
        cta: MyApp.Components.CallToAction
      },
      mdex_options: [extension: [table: true, strikethrough: true]]
    }
end
```

### Component Syntax

Two syntaxes are supported in markdown files.

**Shortcode syntax** — Elixir-style, using atom names:

```
{:callout type: "warning", message: "Be careful here"}
```

**HTML-like syntax** — PascalCase component name, self-closing:

```
<Callout type="warning" message="Be careful here" />
```

Both syntaxes can reference frontmatter values as assigns using `@assign_name`:

```markdown
---
title: Getting Started
version: "2.0"
---

Check out the latest version:

{:callout type: "info", message: @title}

<Callout version={@version} type="info" />
```

### Assign Resolution

Frontmatter values are automatically available as assigns within component attributes. `@assign_name` in shortcode syntax and `{@assign_name}` in HTML-like syntax both resolve to the corresponding frontmatter value.

You can also pass extra assigns at render time:

```elixir
{:ok, entry} = ContentCollections.Entry.render_with_components(post,
  components: %{callout: MyApp.Components.Callout},
  extra_assigns: %{current_user: user}
)
```

### `Entry.render_with_components/2`

Renders an entry using the PhoenixComponent renderer. Metadata is automatically made available as assigns to all embedded components.

```elixir
{:ok, rendered} = ContentCollections.Entry.render_with_components(post,
  components: %{
    callout: MyApp.Components.Callout,
    chart: MyApp.Components.Chart
  }
)
rendered.html
```

Options:

| Option           | Description                                             |
|------------------|---------------------------------------------------------|
| `:components`    | Map of component name (atom) to module                  |
| `:extra_assigns` | Additional assigns merged with frontmatter metadata     |
| `:renderer`      | Override renderer (`{module, opts}` tuple)              |
| `:force`         | Re-render even if HTML is already cached                |

### `Entry.render_with_components!/2`

Raises on error instead of returning an error tuple.

```elixir
entry = ContentCollections.Entry.render_with_components!(post,
  components: %{callout: MyApp.Components.Callout}
)
```

### Security

Only components explicitly listed in the `:components` map can be rendered. Any component reference in markdown that does not match a whitelisted name produces an HTML comment (`<!-- Component error: ... -->`) rather than raising.

Component name matching normalizes PascalCase HTML-like names to snake_case atoms, so `<CallToAction />` resolves to the `:call_to_action` key in your components map.

## Custom Loaders

Implement `ContentCollections.Loader` to load content from any source — a database, an API, a CMS, or a custom file format.

### Behaviour

```elixir
@callback load(opts :: keyword()) :: {:ok, [map()]} | {:error, term()}

# Optional — validated at compile time when the collection is defined
@callback validate_opts(opts :: keyword()) :: :ok | {:error, String.t()}
```

### Entry Map Format

Your `load/1` implementation must return `{:ok, entries}` where each entry is a map with these keys:

| Key         | Required | Description                                        |
|-------------|----------|----------------------------------------------------|
| `:id`       | Yes      | Unique string identifier                           |
| `:slug`     | Yes      | URL-friendly string identifier                      |
| `:content`  | Yes      | Raw content string (usually markdown)              |
| `:metadata` | No       | Map of frontmatter or metadata                     |

### Example: API Loader

```elixir
defmodule MyApp.CMSLoader do
  @behaviour ContentCollections.Loader

  @impl true
  def load(opts) do
    endpoint = Keyword.fetch!(opts, :endpoint)

    case MyApp.CMS.list_articles(endpoint) do
      {:ok, articles} ->
        entries =
          Enum.map(articles, fn article ->
            %{
              id: article.slug,
              slug: article.slug,
              content: article.body,
              metadata: %{
                title: article.title,
                date: article.published_at,
                tags: article.tags
              }
            }
          end)

        {:ok, entries}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def validate_opts(opts) do
    if Keyword.has_key?(opts, :endpoint) do
      :ok
    else
      {:error, "`:endpoint` option is required"}
    end
  end
end

defmodule MyApp.Articles do
  use ContentCollections,
    loader: {MyApp.CMSLoader, endpoint: "/api/v1/articles"},
    compile_time: false
end
```

### Example: Database Loader

```elixir
defmodule MyApp.DatabaseLoader do
  @behaviour ContentCollections.Loader

  @impl true
  def load(opts) do
    schema = Keyword.fetch!(opts, :schema)

    records = MyApp.Repo.all(schema)

    entries =
      Enum.map(records, fn record ->
        %{
          id: to_string(record.id),
          slug: record.slug,
          content: record.body,
          metadata: Map.take(record, [:title, :author, :tags, :published_at])
        }
      end)

    {:ok, entries}
  end
end
```

## Custom Parsers

Implement `ContentCollections.Parser` to support alternative frontmatter formats such as TOML, JSON, or custom delimiters.

### Behaviour

```elixir
@callback parse(content :: String.t()) ::
            {:ok, {metadata :: map(), body :: String.t()}} | {:error, term()}
```

The parser receives the full raw file content and must return a `{metadata_map, body_string}` tuple. If no frontmatter is present, return an empty map and the full content as the body.

### Example: TOML Frontmatter Parser

```elixir
defmodule MyApp.TOMLParser do
  @behaviour ContentCollections.Parser

  @separator "+++"

  @impl true
  def parse(content) do
    case extract_frontmatter(content) do
      {:ok, {frontmatter_str, body}} ->
        case Toml.decode(frontmatter_str) do
          {:ok, metadata} -> {:ok, {metadata, body}}
          {:error, reason} -> {:error, reason}
        end

      :error ->
        {:ok, {%{}, content}}
    end
  end

  defp extract_frontmatter(content) do
    case String.split(content, @separator, parts: 3) do
      ["", frontmatter, body] -> {:ok, {frontmatter, body}}
      _ -> :error
    end
  end
end

defmodule MyApp.Blog do
  use ContentCollections,
    loader: {ContentCollections.Loaders.Filesystem,
      path: "priv/content/**/*.md",
      parser: MyApp.TOMLParser}
end
```

## Custom Renderers

Implement `ContentCollections.Renderer` to use a different markdown library or to post-process rendered HTML.

### Behaviour

```elixir
@callback render(content :: String.t(), opts :: keyword()) ::
            {:ok, String.t()} | {:error, term()}
```

### Example: Post-processing Renderer

Wrap the default MDEx renderer to transform HTML output after rendering:

```elixir
defmodule MyApp.HeadingAnchorRenderer do
  @behaviour ContentCollections.Renderer

  alias ContentCollections.Renderers.MDEx

  @impl true
  def render(content, opts) do
    case MDEx.render(content, opts) do
      {:ok, html} -> {:ok, add_heading_anchors(html)}
      error -> error
    end
  end

  defp add_heading_anchors(html) do
    Regex.replace(~r/<h([2-4])>([^<]+)<\/h\1>/, html, fn _, level, text ->
      id = text |> String.downcase() |> String.replace(~r/[^\w]+/, "-")
      "<h#{level} id=\"#{id}\">#{text}</h#{level}>"
    end)
  end
end

defmodule MyApp.Docs do
  use ContentCollections,
    loader: {ContentCollections.Loaders.Filesystem, path: "priv/docs/**/*.md"},
    renderer: MyApp.HeadingAnchorRenderer
end
```

## Compile-time vs Runtime Loading

ContentCollections supports two loading strategies. The right choice depends on your deployment model and content update frequency.

### Compile-time Loading (`compile_time: true`)

Content is loaded once during compilation and stored as module attributes. At runtime, queries read directly from in-memory data structures with no filesystem access.

**Best for:**
- Production deployments where content changes infrequently
- Static sites or documentation built from a CI pipeline
- Maximum query performance with zero I/O overhead

**Tradeoffs:**
- Content updates require recompilation and redeployment
- `reload/0` returns `{:error, :compile_time_collection}`
- Compilation time increases with content volume

```elixir
defmodule MyApp.Blog do
  use ContentCollections,
    loader: {ContentCollections.Loaders.Filesystem, path: "priv/content/**/*.md"},
    compile_time: true
end
```

### Runtime Loading (`compile_time: false`)

Content is loaded on first access at runtime by calling the loader directly. By default, entries are cached after the first load and can be explicitly reloaded without restarting the application.

**Best for:**
- Development — content changes are reflected without recompilation
- CMS-backed content that updates independently of deploys
- Large content volumes where compile-time embedding is impractical

**Tradeoffs:**
- First access incurs I/O or network overhead
- With `cache: false`, every query incurs I/O or network overhead
- Content is not verified at compile time

```elixir
defmodule MyApp.Blog do
  use ContentCollections,
    loader: {ContentCollections.Loaders.Filesystem, path: "priv/content/**/*.md"},
    compile_time: false
end
```

### Recommended Pattern

Use `Mix.env()` to get compile-time loading in production and runtime loading during development:

```elixir
defmodule MyApp.Blog do
  use ContentCollections,
    loader: {ContentCollections.Loaders.Filesystem,
      path: "priv/content/blog/**/*.md"},
    compile_time: Mix.env() == :prod
end
```

## License

MIT
