defmodule ContentCollections.Parsers.YAML do
  @moduledoc """
  YAML frontmatter parser for content collections.

  Parses content with YAML frontmatter delimited by `---` markers.

  ## Format

      ---
      title: My Post
      date: 2024-01-15
      author: Jane Doe
      tags:
        - elixir
        - phoenix
      published: true
      ---

      # My Post

      Post content goes here...

  ## Options

  This parser currently accepts no options, but the interface allows
  for future extensibility.
  """

  @behaviour ContentCollections.Parser

  @frontmatter_separator "---"

  @impl true
  def parse(content) when is_binary(content) do
    case extract_frontmatter(content) do
      {:ok, {frontmatter, body}} ->
        parse_yaml_frontmatter(frontmatter, body)

      :error ->
        {:ok, {%{}, content}}
    end
  end

  defp extract_frontmatter(content) do
    lines = String.split(content, "\n")

    case lines do
      [@frontmatter_separator | rest] ->
        extract_frontmatter_from_lines(rest, [])

      _ ->
        :error
    end
  end

  defp extract_frontmatter_from_lines([], _acc) do
    :error
  end

  defp extract_frontmatter_from_lines([@frontmatter_separator | rest], acc) do
    frontmatter = acc |> Enum.reverse() |> Enum.join("\n")
    body = Enum.join(rest, "\n")
    {:ok, {frontmatter, body}}
  end

  defp extract_frontmatter_from_lines([line | rest], acc) do
    extract_frontmatter_from_lines(rest, [line | acc])
  end

  defp parse_yaml_frontmatter(frontmatter, body) do
    case YamlElixir.read_from_string(frontmatter) do
      {:ok, metadata} when is_map(metadata) ->
        {:ok, {metadata, body}}

      {:ok, _} ->
        {:error, :invalid_frontmatter_format}

      {:error, %YamlElixir.ParsingError{} = error} ->
        {:error, format_yaml_error(error)}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e ->
      {:error, Exception.message(e)}
  end

  defp format_yaml_error(%YamlElixir.ParsingError{} = error) do
    "YAML parsing error: #{error.message} at line #{error.line}, column #{error.column}"
  end
end
