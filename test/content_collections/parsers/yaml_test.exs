defmodule ContentCollections.Parsers.YAMLTest do
  use ExUnit.Case, async: true

  alias ContentCollections.Parsers.YAML

  test "parses YAML frontmatter and body" do
    content = """
    ---
    title: Hello
    published: true
    ---
    # Heading
    """

    assert {:ok, {metadata, body}} = YAML.parse(content)
    assert metadata["title"] == "Hello"
    assert metadata["published"] == true
    assert body == "# Heading\n"
  end

  test "returns empty metadata when no frontmatter exists" do
    content = "# Plain markdown"
    assert {:ok, {%{}, ^content}} = YAML.parse(content)
  end

  test "returns empty metadata when closing frontmatter delimiter is missing" do
    content = "---\ntitle: Incomplete\n# Missing closing delimiter"
    assert {:ok, {%{}, ^content}} = YAML.parse(content)
  end

  test "returns invalid_frontmatter_format when yaml decodes to non-map" do
    content = """
    ---
    - one
    - two
    ---
    body
    """

    assert {:error, :invalid_frontmatter_format} = YAML.parse(content)
  end

  test "returns readable parse errors for malformed yaml" do
    content = """
    ---
    title: [unclosed
    ---
    body
    """

    assert {:error, message} = YAML.parse(content)
    assert is_binary(message)
    assert String.contains?(message, "YAML parsing error")
  end
end
