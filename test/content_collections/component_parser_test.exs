defmodule ContentCollections.ComponentParserTest do
  use ExUnit.Case, async: true

  alias ContentCollections.ComponentParser

  test "parse/1 parses shortcode attrs with typed values" do
    component = "{:weather city: \"Phoenix\", unit: @temp_unit, temp: 75, celsius: false}"

    assert {:ok, parsed} = ComponentParser.parse(component)
    assert parsed.type == :shortcode
    assert parsed.name == :weather
    assert parsed.attrs.city == "Phoenix"
    assert parsed.attrs.unit == {:assign, :temp_unit}
    assert parsed.attrs.temp == 75
    assert parsed.attrs.celsius == false
  end

  test "parse/1 parses html-like attrs" do
    component = "<Weather city=\"Phoenix\" unit={@temp_unit} />"

    assert {:ok, parsed} = ComponentParser.parse(component)
    assert parsed.type == :html_like
    assert parsed.name == "Weather"
    assert parsed.attrs.city == {:string, "Phoenix"}
    assert parsed.attrs.unit == {:assign, :temp_unit}
  end

  test "parse/1 supports shortcode without attrs" do
    assert {:ok, parsed} = ComponentParser.parse("{:weather}")
    assert parsed.type == :shortcode
    assert parsed.name == :weather
    assert parsed.attrs == %{}
  end

  test "parse/1 supports float and bare string attr values" do
    assert {:ok, parsed} = ComponentParser.parse("{:card score: 98.5, status: active}")
    assert parsed.attrs.score == 98.5
    assert parsed.attrs.status == "active"
  end

  test "parse/1 rejects invalid syntax" do
    assert {:error, "Invalid component syntax"} = ComponentParser.parse("[not-a-component]")
  end

  test "find_components/1 returns shortcodes and html-like components in order" do
    content = "Before {:card title: \"A\"} middle <Weather city=\"Phoenix\" /> after"

    components = ComponentParser.find_components(content)

    assert length(components) == 2
    [{start_one, _, first}, {start_two, _, second}] = components
    assert start_one < start_two
    assert first.type == :shortcode
    assert second.type == :html_like
  end

  test "replace_components/2 replaces multiple placeholders correctly" do
    content = "A {:card title: \"x\"} B <Weather city=\"Phoenix\" /> C"

    [first, second] = ComponentParser.find_components(content)

    replacements = [
      {elem(first, 0), elem(first, 1), "<div>card</div>"},
      {elem(second, 0), elem(second, 1), "<span>weather</span>"}
    ]

    replaced = ComponentParser.replace_components(content, replacements)

    assert replaced == "A <div>card</div> B <span>weather</span> C"
  end
end
