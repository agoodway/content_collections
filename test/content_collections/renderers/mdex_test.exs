defmodule ContentCollections.Renderers.MDExTest do
  use ExUnit.Case, async: true

  alias ContentCollections.Renderers.MDEx

  test "renders markdown to html" do
    assert {:ok, html} = MDEx.render("# Hello", [])
    assert html =~ "<h1>Hello</h1>"
  end

  test "accepts custom extension/parse/render opts" do
    assert {:ok, html} =
             MDEx.render("~~gone~~", extension: [strikethrough: true], parse: [smart: false])

    assert html =~ "<del>gone</del>"
  end

  test "supports sanitize false code path" do
    assert {:ok, html} = MDEx.render("<b>x</b>", sanitize: false)
    assert html =~ "<b>x</b>"
  end

  test "returns mdex error tuple when options are invalid" do
    assert {:error, {error_type, message}} = MDEx.render("# Hello", extension: [table: "yes"])
    assert error_type in [:mdex_error, :render_error]
    assert is_binary(message)
  end
end
