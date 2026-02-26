defmodule ContentCollections.Loaders.Filesystem do
  @moduledoc """
  A filesystem loader for content collections.

  Loads markdown files from the filesystem, parsing frontmatter and content.

  ## Options

  - `:path` - Glob pattern for finding files (required)
  - `:parser` - Parser module for frontmatter (defaults to YAML parser)
  - `:base_path` - Base path for resolving relative paths (defaults to File.cwd!)

  ## Examples

      # Load all markdown files from a directory
      use ContentCollections,
        loader: {ContentCollections.Loaders.Filesystem,
          path: "content/blog/**/*.md"}

      # With custom base path
      use ContentCollections,
        loader: {ContentCollections.Loaders.Filesystem,
          path: "posts/**/*.{md,mdx}",
          base_path: "/app/content"}
  """

  @behaviour ContentCollections.Loader

  alias ContentCollections.Entry

  @impl true
  def load(opts) do
    with {:ok, path_pattern} <- validate_required_opts(opts),
         {:ok, files} <- find_files(path_pattern, opts) do
      load_files(files, opts)
    end
  end

  @impl true
  def validate_opts(opts) do
    case Keyword.fetch(opts, :path) do
      {:ok, path} when is_binary(path) ->
        :ok

      {:ok, _} ->
        {:error, "Path option must be a string"}

      :error ->
        {:error, "Path option is required"}
    end
  end

  defp validate_required_opts(opts) do
    case Keyword.fetch(opts, :path) do
      {:ok, path} -> {:ok, path}
      :error -> {:error, "Path option is required"}
    end
  end

  defp find_files(pattern, opts) do
    base_path = Keyword.get(opts, :base_path, File.cwd!())
    full_pattern = Path.join(base_path, pattern)

    files =
      full_pattern
      |> Path.wildcard()
      |> Enum.filter(&File.regular?/1)
      |> Enum.sort()

    {:ok, files}
  end

  defp load_files(files, opts) do
    parser = get_parser(opts)

    results =
      Enum.map(files, fn file ->
        with {:ok, content} <- File.read(file),
             {:ok, {metadata, body}} <- parser.parse(content) do
          build_entry(file, metadata, body, opts)
        else
          {:error, reason} ->
            {:error, {file, reason}}
        end
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      {:ok, Enum.map(results, fn {:ok, entry} -> entry end)}
    else
      {:error, {:failed_files, errors}}
    end
  end

  defp get_parser(opts) do
    case Keyword.get(opts, :parser) do
      nil ->
        ContentCollections.Parsers.YAML

      {module, _opts} ->
        module

      module when is_atom(module) ->
        module
    end
  end

  defp build_entry(file_path, metadata, content, opts) do
    base_path = Keyword.get(opts, :base_path, File.cwd!())
    relative_path = Path.relative_to(file_path, base_path)
    slug = Entry.slug_from_path(file_path)

    # Use file path as ID if no ID in metadata
    id = Map.get(metadata, "id", relative_path)

    entry = %{
      id: id,
      slug: slug,
      content: content,
      metadata: normalize_metadata(metadata)
    }

    {:ok, entry}
  end

  defp normalize_metadata(metadata) do
    # Convert string keys to atoms for common fields
    metadata
    |> Enum.map(fn
      {"title", value} -> {:title, value}
      {"date", value} -> {:date, parse_date(value)}
      {"tags", value} -> {:tags, parse_tags(value)}
      {"published", value} -> {:published, parse_boolean(value)}
      {"draft", value} -> {:draft, parse_boolean(value)}
      {key, value} when is_binary(key) -> {String.to_atom(key), value}
      {key, value} -> {key, value}
    end)
    |> Map.new()
  end

  defp parse_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, date} -> date
      _ -> date
    end
  end

  defp parse_date(date), do: date

  defp parse_tags(tags) when is_list(tags), do: tags

  defp parse_tags(tags) when is_binary(tags) do
    tags
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
  end

  defp parse_tags(_), do: []

  defp parse_boolean(true), do: true
  defp parse_boolean(false), do: false
  defp parse_boolean("true"), do: true
  defp parse_boolean("false"), do: false
  defp parse_boolean(_), do: false
end
