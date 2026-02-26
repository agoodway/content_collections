defmodule ContentCollections.RendererTest do
  use ExUnit.Case, async: true

  alias ContentCollections.Renderer
  alias ContentCollections.Renderers.MDEx

  test "normalize/1 defaults to MDEx" do
    assert Renderer.normalize(nil) == {MDEx, []}
  end

  test "normalize/1 accepts module or {module, opts}" do
    assert Renderer.normalize(MDEx) == {MDEx, []}

    assert Renderer.normalize({MDEx, extension: [table: true]}) ==
             {MDEx, extension: [table: true]}
  end

  test "normalize/1 raises for invalid renderer spec" do
    assert_raise ArgumentError, ~r/Invalid renderer specification/, fn ->
      Renderer.normalize({"bad", []})
    end
  end
end
