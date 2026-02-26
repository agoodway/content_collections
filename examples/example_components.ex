defmodule ContentCollections.ExampleComponents do
  @moduledoc """
  Example Phoenix components for testing and demonstration.

  These components show how to create components that can be embedded
  in markdown files using the ContentCollections system.
  """

  use Phoenix.Component

  @doc """
  A simple weather component that displays weather information.
  """
  attr :city, :string, required: true
  attr :unit, :string, default: "F"
  attr :show_current, :boolean, default: true
  attr :temp, :integer, default: 75

  def weather(assigns) do
    ~H"""
    <div class="weather-widget">
      <h3>Weather in {@city}</h3>
      <%= if @show_current do %>
        <div class="current-temp">
          <span class="temp">{@temp}°{@unit}</span>
          <span class="conditions">Sunny</span>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  A city fact component that displays information about a city.
  """
  attr :city, :string, required: true
  attr :fact_type, :string, default: "general"

  def city_fact(assigns) do
    fact = get_city_fact(assigns.city, assigns.fact_type)

    assigns = assign(assigns, :fact, fact)

    ~H"""
    <div class="city-fact">
      <strong>{@fact_type}:</strong> {@fact}
    </div>
    """
  end

  @doc """
  A weather forecast component.
  """
  attr :city, :string, required: true
  attr :days, :integer, default: 5
  attr :unit, :string, default: "F"
  attr :detailed, :boolean, default: false

  def weather_forecast(assigns) do
    ~H"""
    <div class="weather-forecast">
      <h4>{@days}-Day Forecast for {@city}</h4>
      <div class="forecast-grid">
        <%= for day <- 1..@days do %>
          <div class="forecast-day">
            <div class="day">Day {day}</div>
            <div class="high">H: {70 + day}°{@unit}</div>
            <div class="low">L: {50 + day}°{@unit}</div>
            <%= if @detailed do %>
              <div class="conditions">Partly Cloudy</div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  A simple text component that displays a greeting.
  """
  attr :name, :string, default: "World"
  attr :greeting, :string, default: "Hello"

  def greeting(assigns) do
    ~H"""
    <p class="greeting">
      {@greeting}, {@name}!
    </p>
    """
  end

  # Helper function to simulate getting city facts
  defp get_city_fact("Phoenix", "population"), do: "1,660,272 (2021)"
  defp get_city_fact("Phoenix", "elevation"), do: "1,086 ft (331 m)"
  defp get_city_fact(city, "population"), do: "Population data for #{city}"
  defp get_city_fact(city, "elevation"), do: "Elevation data for #{city}"
  defp get_city_fact(city, _), do: "#{city} is a great city!"
end
