defmodule ContentCollections.EntryTest do
  use ExUnit.Case, async: true

  alias ContentCollections.Entry
  alias ContentCollections.TestSupport.FakeRenderer

  defmodule CaptureRenderer do
    @behaviour ContentCollections.Renderer

    @impl true
    def render(content, opts) do
      assigns = Keyword.get(opts, :assigns, %{})
      {:ok, "#{content}|#{inspect(assigns)}"}
    end
  end

  defmodule CollectionWithRenderer do
    def __renderer__, do: {FakeRenderer, []}
  end

  test "new/1 enforces required keys" do
    assert_raise ArgumentError, fn -> Entry.new(slug: "post", content: "# Hello") end
  end

  test "render/2 returns cached html unless force is set" do
    entry = %Entry{id: "1", slug: "post", content: "# Hello", html: "<p>cached</p>"}

    assert {:ok, returned} = Entry.render(entry, renderer: {FakeRenderer, [fail: true]})
    assert returned.html == "<p>cached</p>"

    assert {:error, :render_failed} =
             Entry.render(entry, renderer: {FakeRenderer, [fail: true]}, force: true)
  end

  test "render/2 uses collection renderer when no explicit renderer is provided" do
    entry = %Entry{id: "1", slug: "post", content: "body", collection: CollectionWithRenderer}

    assert {:ok, rendered} = Entry.render(entry)
    assert rendered.html == "<p>body</p>"
  end

  test "explicit renderer takes precedence over collection renderer" do
    entry = %Entry{id: "1", slug: "post", content: "body", collection: CollectionWithRenderer}

    assert {:error, :render_failed} = Entry.render(entry, renderer: {FakeRenderer, [fail: true]})
  end

  test "render!/2 and to_html!/2 raise on renderer error" do
    entry = %Entry{id: "1", slug: "post", content: "body"}

    assert_raise RuntimeError, ~r/Failed to render entry/, fn ->
      Entry.render!(entry, renderer: {FakeRenderer, [fail: true]})
    end

    assert_raise RuntimeError, ~r/Failed to render entry/, fn ->
      Entry.to_html!(entry, renderer: {FakeRenderer, [fail: true]})
    end
  end

  test "to_html/2 renders when html is missing" do
    entry = %Entry{id: "1", slug: "post", content: "body"}

    assert {:ok, "<p>body</p>"} = Entry.to_html(entry, renderer: FakeRenderer)
  end

  test "render_with_components/2 builds assigns from metadata and extra assigns" do
    entry =
      %Entry{
        id: "1",
        slug: "post",
        content: "body",
        metadata: %{"city" => "Phoenix", title: "Forecast"}
      }

    assert {:ok, rendered} =
             Entry.render_with_components(entry,
               renderer: {CaptureRenderer, %{}},
               extra_assigns: [unit: "F"]
             )

    assert rendered.html =~ "city: \"Phoenix\""
    assert rendered.html =~ "title: \"Forecast\""
    assert rendered.html =~ "unit: \"F\""
  end

  test "render_with_components!/2 raises on render error" do
    entry = %Entry{id: "1", slug: "post", content: "body", metadata: %{}}

    assert_raise RuntimeError, ~r/Failed to render entry with components/, fn ->
      Entry.render_with_components!(entry, renderer: {FakeRenderer, [fail: true]})
    end
  end

  test "render_with_components/2 normalizes invalid extra_assigns to empty map" do
    entry = %Entry{id: "1", slug: "post", content: "body", metadata: %{}}

    assert {:ok, rendered} =
             Entry.render_with_components(entry,
               renderer: {CaptureRenderer, %{}},
               extra_assigns: :invalid
             )

    assert rendered.html =~ "%{}"
  end

  test "slug_from_path/1 extracts filename without extension" do
    assert Entry.slug_from_path("content/blog/hello-world.md") == "hello-world"
  end
end
