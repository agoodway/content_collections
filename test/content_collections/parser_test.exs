defmodule ContentCollections.ParserTest do
  use ExUnit.Case, async: true

  alias ContentCollections.Parser
  alias ContentCollections.Parsers.YAML

  test "normalize/1 uses YAML parser by default" do
    assert Parser.normalize(nil) == YAML
  end

  test "normalize/1 accepts module or {module, opts}" do
    assert Parser.normalize(YAML) == YAML
    assert Parser.normalize({YAML, foo: :bar}) == YAML
  end

  test "normalize/1 raises for invalid parser spec" do
    assert_raise ArgumentError, ~r/Invalid parser specification/, fn ->
      Parser.normalize({"not_a_module", []})
    end
  end
end
