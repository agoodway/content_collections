defmodule ContentCollections.Renderers.PhoenixComponentTest do
  use ExUnit.Case, async: true

  alias ContentCollections.Renderers.PhoenixComponent
  alias ContentCollections.TestSupport.SampleComponents

  defmodule NoFunctionsComponent do
  end

  test "requires configured components" do
    assert {:error, message} = PhoenixComponent.render("hello", [])
    assert String.contains?(message, "No components configured")
  end

  test "validates assigns type" do
    assert {:error, "Invalid assigns. Expected map or keyword list"} =
             PhoenixComponent.render("hello", components: %{}, assigns: :bad)
  end

  test "renders shortcode component with assign resolution" do
    content = "Weather: {:weather city: @city, unit: \"F\"}"

    assert {:ok, html} =
             PhoenixComponent.render(content,
               components: %{weather: SampleComponents},
               assigns: %{city: "Phoenix"}
             )

    assert html =~ "<span data-component=\"weather\">Phoenix-F</span>"
  end

  test "normalizes html-like component name and resolves @assign syntax" do
    content = "<Weather city={@city} unit={unit} />"

    assert {:ok, html} =
             PhoenixComponent.render(content,
               components: %{weather: SampleComponents},
               assigns: %{city: "Tempe", unit: "C"}
             )

    assert html =~ "<span data-component=\"weather\">Tempe-C</span>"
  end

  test "unknown components render an html comment placeholder" do
    content = "{:unknown title: \"x\"}"

    assert {:ok, html} =
             PhoenixComponent.render(content,
               components: %{weather: SampleComponents},
               assigns: %{}
             )

    assert html =~ "<!-- Component error: Component 'unknown' not found in whitelist -->"
  end

  test "returns component function missing error as placeholder" do
    content = "{:weather city: \"Phoenix\"}"

    assert {:ok, html} =
             PhoenixComponent.render(content,
               components: %{weather: NoFunctionsComponent},
               assigns: %{}
             )

    assert html =~ "<!-- Component error: No function 'weather' found in component module -->"
  end
end
