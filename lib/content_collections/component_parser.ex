defmodule ContentCollections.ComponentParser do
  @moduledoc """
  Parses component syntax from markdown content.

  Supports two syntax styles for embedding Phoenix components:

  1. **Shortcode style**: `{:component_name key: value, key2: value2}`
  2. **HTML-like style**: `<ComponentName key="value" key2={@assign} />`

  ## Examples

      iex> ComponentParser.parse("{:weather city: \"Phoenix\", unit: \"F\"}")
      {:ok, %{type: :shortcode, name: :weather, attrs: %{city: "Phoenix", unit: "F"}}}

      iex> ComponentParser.parse("<Weather city=\"Phoenix\" unit={@temp_unit} />")
      {:ok, %{type: :html_like, name: "Weather", attrs: %{city: {:string, "Phoenix"}, unit: {:assign, :temp_unit}}}}
  """

  @shortcode_regex ~r/\{:(\w+)(?:\s+(.+?))?\}/
  @html_like_regex ~r/<(\w+)(?:\s+([^>\/]+))?\s*\/>/
  @attr_regex ~r/(\w+):\s*([^,]+?)(?:,\s*|$)/
  @html_attr_regex ~r/(\w+)=(?:"([^"]*)"|{(@?\w+)})/

  @doc """
  Finds all components in the given content and returns their positions and parsed data.
  """
  @spec find_components(String.t()) :: [{pos_integer(), pos_integer(), map()}]
  def find_components(content) do
    shortcodes = find_shortcode_components(content)
    html_like = find_html_like_components(content)

    (shortcodes ++ html_like)
    |> Enum.sort_by(fn {start, _, _} -> start end)
  end

  @doc """
  Parses a single component string.
  """
  @spec parse(String.t()) :: {:ok, map()} | {:error, String.t()}
  def parse(component_string) do
    cond do
      String.starts_with?(component_string, "{:") ->
        parse_shortcode(component_string)

      String.starts_with?(component_string, "<") ->
        parse_html_like(component_string)

      true ->
        {:error, "Invalid component syntax"}
    end
  end

  defp find_shortcode_components(content) do
    @shortcode_regex
    |> Regex.scan(content, return: :index)
    |> Enum.map(fn [{start, length} | _] ->
      component = String.slice(content, start, length)

      case parse_shortcode(component) do
        {:ok, parsed} -> {start, length, parsed}
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp find_html_like_components(content) do
    @html_like_regex
    |> Regex.scan(content, return: :index)
    |> Enum.map(fn [{start, length} | _] ->
      component = String.slice(content, start, length)

      case parse_html_like(component) do
        {:ok, parsed} -> {start, length, parsed}
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_shortcode(component_string) do
    case Regex.run(@shortcode_regex, component_string) do
      [_, name] ->
        {:ok,
         %{
           type: :shortcode,
           name: String.to_atom(name),
           attrs: %{}
         }}

      [_, name, attrs_string] ->
        case parse_shortcode_attrs(attrs_string) do
          {:ok, attrs} ->
            {:ok,
             %{
               type: :shortcode,
               name: String.to_atom(name),
               attrs: attrs
             }}

          error ->
            error
        end

      _ ->
        {:error, "Invalid shortcode syntax"}
    end
  end

  defp parse_html_like(component_string) do
    case Regex.run(@html_like_regex, component_string) do
      [_, name] ->
        {:ok,
         %{
           type: :html_like,
           name: name,
           attrs: %{}
         }}

      [_, name, attrs_string] ->
        attrs = parse_html_attrs(attrs_string)

        {:ok,
         %{
           type: :html_like,
           name: name,
           attrs: attrs
         }}

      _ ->
        {:error, "Invalid HTML-like component syntax"}
    end
  end

  defp parse_shortcode_attrs(attrs_string) do
    attrs =
      @attr_regex
      |> Regex.scan(attrs_string)
      |> Enum.map(fn [_, key, value] ->
        {String.to_atom(key), parse_attr_value(value)}
      end)
      |> Map.new()

    {:ok, attrs}
  rescue
    _ -> {:error, "Failed to parse attributes"}
  end

  defp parse_html_attrs(attrs_string) do
    attrs_string = String.trim(attrs_string)

    @html_attr_regex
    |> Regex.scan(attrs_string)
    |> Enum.map(fn
      [_, key, value, ""] when value != "" ->
        {String.to_atom(key), {:string, value}}

      [_, key, "", assign] when assign != "" ->
        assign_name =
          if String.starts_with?(assign, "@"),
            do: String.slice(assign, 1..-1//1) |> String.to_atom(),
            else: String.to_atom(assign)

        {String.to_atom(key), {:assign, assign_name}}

      [_, key, value] when value != "" ->
        # Handle case where there's no assign capture group
        {String.to_atom(key), {:string, value}}

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp parse_attr_value(value) do
    value = String.trim(value)

    cond do
      String.starts_with?(value, "\"") ->
        parse_string_literal(value)

      String.starts_with?(value, "@") ->
        parse_assign_reference(value)

      number?(value) ->
        parse_number(value)

      boolean?(value) ->
        parse_boolean(value)

      # Default to string - remove trailing comma
      true ->
        String.trim_trailing(value, ",")
    end
  end

  defp number?(value) do
    case Integer.parse(value) do
      {_, ""} ->
        true

      _ ->
        case Float.parse(value) do
          {_, ""} -> true
          _ -> false
        end
    end
  end

  defp boolean?(value) do
    trimmed = String.trim_trailing(value, ",")
    trimmed == "true" or trimmed == "false"
  end

  defp parse_string_literal(value) do
    if String.starts_with?(value, "\"") do
      # Remove trailing comma if present
      value = if String.ends_with?(value, ","), do: String.slice(value, 0..-2//1), else: value

      if String.ends_with?(value, "\"") do
        String.slice(value, 1..-2//1)
      else
        value
      end
    end
  end

  defp parse_assign_reference(value) do
    if String.starts_with?(value, "@") do
      cleaned =
        value
        |> String.trim_trailing(",")
        |> String.slice(1..-1//1)
        |> String.trim()
        |> String.to_atom()

      {:assign, cleaned}
    end
  end

  defp parse_number(value) do
    case Integer.parse(value) do
      {num, ""} ->
        num

      _ ->
        case Float.parse(value) do
          {num, ""} -> num
          _ -> nil
        end
    end
  end

  defp parse_boolean(value) do
    case String.trim_trailing(value, ",") do
      "true" -> true
      "false" -> false
      _ -> nil
    end
  end

  @doc """
  Replaces component placeholders in content with rendered HTML.
  """
  @spec replace_components(String.t(), [{pos_integer(), pos_integer(), String.t()}]) :: String.t()
  def replace_components(content, replacements) do
    # Sort replacements by position in reverse order to avoid offset issues
    sorted_replacements = Enum.sort_by(replacements, fn {start, _, _} -> start end, :desc)

    Enum.reduce(sorted_replacements, content, fn {start, length, html}, acc ->
      String.slice(acc, 0, start) <> html <> String.slice(acc, start + length, String.length(acc))
    end)
  end
end
