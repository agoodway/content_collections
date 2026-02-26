defmodule ContentCollections.Renderers.PhoenixComponent do
  @moduledoc """
  Renderer that supports embedding Phoenix components in markdown.

  This renderer extends MDEx to parse and render Phoenix components
  embedded in markdown content. Components can access frontmatter
  metadata as assigns.

  ## Configuration

      use ContentCollections,
        renderer: {ContentCollections.Renderers.PhoenixComponent,
          components: %{
            weather: MyApp.WeatherComponent,
            city_fact: MyApp.CityFactComponent
          },
          mdex_options: [extension: [table: true, strikethrough: true]]
        }

  ## Component Syntax

  Two syntax styles are supported:

  1. **Shortcode style**: `{:weather city: @city, temp: 75}`
  2. **HTML-like style**: `<Weather city={@city} temp="75" />`

  ## Security

  Only whitelisted components can be rendered. Component names must be
  explicitly configured in the renderer options.
  """

  @behaviour ContentCollections.Renderer

  alias ContentCollections.ComponentParser
  alias ContentCollections.Renderers.MDEx, as: MDExRenderer

  @impl true
  def render(content, opts \\ []) when is_binary(content) do
    with {:ok, components_map} <- validate_components(opts),
         {:ok, _assigns} <- validate_assigns(opts) do
      render_with_components(content, opts, components_map)
    end
  end

  defp validate_components(opts) do
    case Keyword.get(opts, :components) do
      nil ->
        {:error, "No components configured. Add components: %{name: Module} to renderer options"}

      components when is_map(components) ->
        {:ok, components}

      components when is_list(components) ->
        {:ok, Map.new(components)}

      _ ->
        {:error, "Invalid components configuration. Expected map or keyword list"}
    end
  end

  defp validate_assigns(opts) do
    assigns = Keyword.get(opts, :assigns, %{})

    if is_map(assigns) or is_list(assigns) do
      {:ok, assigns}
    else
      {:error, "Invalid assigns. Expected map or keyword list"}
    end
  end

  defp render_with_components(content, opts, components_map) do
    # Find all components in the content
    components = ComponentParser.find_components(content)

    # Get assigns from options
    assigns = opts |> Keyword.get(:assigns, %{}) |> normalize_assigns()

    # Render each component
    rendered_components =
      components
      |> Enum.map(fn {start, length, component_data} ->
        case render_component(component_data, assigns, components_map, opts) do
          {:ok, html} -> {start, length, html}
          {:error, reason} -> {start, length, "<!-- Component error: #{reason} -->"}
        end
      end)

    # Replace components with their rendered HTML
    content_with_components = ComponentParser.replace_components(content, rendered_components)

    # Render the markdown with MDEx
    mdex_opts =
      opts
      |> Keyword.get(:mdex_options, [])
      # Don't sanitize since components are already safe
      |> Keyword.put(:sanitize, false)

    MDExRenderer.render(content_with_components, mdex_opts)
  end

  defp normalize_assigns(assigns) when is_map(assigns), do: assigns
  defp normalize_assigns(assigns) when is_list(assigns), do: Map.new(assigns)
  defp normalize_assigns(_), do: %{}

  defp render_component(component_data, assigns, components_map, _opts) do
    %{name: name, attrs: attrs} = component_data

    # Look up the component module
    component_name = normalize_component_name(name)

    case Map.get(components_map, component_name) do
      nil ->
        {:error, "Component '#{component_name}' not found in whitelist"}

      component_module ->
        # Resolve attributes with assigns
        resolved_attrs = resolve_attrs(attrs, assigns)

        # Render the component with the component name
        render_phoenix_component(component_module, component_name, resolved_attrs)
    end
  end

  defp normalize_component_name(name) when is_atom(name), do: name

  defp normalize_component_name(name) when is_binary(name) do
    name
    |> Macro.underscore()
    |> String.to_atom()
  end

  defp resolve_attrs(attrs, assigns) do
    attrs
    |> Enum.map(fn
      {key, {:assign, assign_name}} ->
        {key, Map.get(assigns, assign_name)}

      {key, {:string, value}} ->
        {key, value}

      {key, value} ->
        {key, value}
    end)
    |> Map.new()
  end

  defp render_phoenix_component(component_module, component_name, attrs) do
    try do
      # Always try as a function component first
      render_function_component(component_module, component_name, attrs)
    rescue
      e ->
        {:error, "Failed to render component: #{Exception.message(e)}"}
    end
  end

  defp render_function_component(component_module, component_name, attrs) do
    # Build assigns
    assigns = Map.merge(%{__changed__: %{}}, attrs)

    # Try to call the function with the component name
    if function_exported?(component_module, component_name, 1) do
      result = apply(component_module, component_name, [assigns])
      html = render_component_result(result)
      {:ok, html}
    else
      {:error, "No function '#{component_name}' found in component module"}
    end
  end

  defp render_component_result(result) when is_binary(result), do: result

  if Code.ensure_loaded?(Phoenix.LiveView.Rendered) do
    defp render_component_result(%Phoenix.LiveView.Rendered{} = rendered) do
      Phoenix.HTML.Safe.to_iodata(rendered)
      |> IO.iodata_to_binary()
    end
  end

  defp render_component_result(result) do
    # Try to convert to string using protocol if available
    try do
      Phoenix.HTML.Safe.to_iodata(result)
      |> IO.iodata_to_binary()
    rescue
      _ ->
        # Fallback to inspect if protocol not available
        inspect(result)
    end
  end
end
