defmodule ContentCollections.Parser do
  @moduledoc """
  Behavior for content parsers.

  A parser is responsible for extracting frontmatter metadata and content
  from raw file content. The most common format is YAML frontmatter delimited
  by `---` markers.

  ## Implementing a Parser

      defmodule MyApp.TOMLParser do
        @behaviour ContentCollections.Parser

        @impl true
        def parse(content) do
          # Parse TOML frontmatter
          case extract_toml_frontmatter(content) do
            {:ok, {frontmatter, body}} ->
              metadata = Toml.decode!(frontmatter)
              {:ok, {metadata, body}}

            :error ->
              {:ok, {%{}, content}}
          end
        end
      end

  ## Frontmatter Format

  The default YAML parser expects content in this format:

      ---
      title: My Post
      date: 2024-01-15
      tags:
        - elixir
        - web
      ---

      # My Post

      Post content goes here...
  """

  @doc """
  Parses content to extract metadata and body.

  Returns a tuple of metadata map and remaining content.
  If no frontmatter is found, returns an empty metadata map
  and the full content as body.

  ## Examples

      iex> content = \"\"\"
      ...> ---
      ...> title: Hello
      ...> ---
      ...> # Hello World
      ...> \"\"\"
      iex> MyParser.parse(content)
      {:ok, {%{"title" => "Hello"}, "# Hello World\\n"}}

      iex> MyParser.parse("# Just content")
      {:ok, {%{}, "# Just content"}}
  """
  @callback parse(content :: String.t()) ::
              {:ok, {metadata :: map(), body :: String.t()}} | {:error, term()}

  @doc """
  Normalizes parser specification into a module.
  """
  @spec normalize(parser :: module() | {module(), keyword()}) :: module()
  def normalize(nil), do: ContentCollections.Parsers.YAML
  def normalize(parser) when is_atom(parser), do: parser
  def normalize({parser, _opts}) when is_atom(parser), do: parser

  def normalize(other) do
    raise ArgumentError, """
    Invalid parser specification: #{inspect(other)}

    Expected a module or {module, options} tuple.
    """
  end
end
