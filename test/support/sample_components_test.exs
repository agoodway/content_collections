defmodule ContentCollections.TestSupport.SampleComponents do
  def weather(assigns) do
    city = Map.get(assigns, :city, "unknown")
    unit = Map.get(assigns, :unit, "F")
    "<span data-component=\"weather\">#{city}-#{unit}</span>"
  end

  def card(assigns) do
    title = Map.get(assigns, :title, "untitled")
    "<div data-component=\"card\">#{title}</div>"
  end
end
