defmodule ContentCollections.TestSupport.FakeParser do
  @behaviour ContentCollections.Parser

  @impl true
  def parse(content) do
    case content do
      "parse-error" -> {:error, :parse_error}
      _ -> {:ok, {%{"title" => "From parser"}, content}}
    end
  end
end

defmodule ContentCollections.TestSupport.FakeRenderer do
  @behaviour ContentCollections.Renderer

  @impl true
  def render(content, opts) do
    if Keyword.get(opts, :fail, false) do
      {:error, :render_failed}
    else
      {:ok, "<p>#{content}</p>"}
    end
  end
end

defmodule ContentCollections.TestSupport.FakeLoader do
  @behaviour ContentCollections.Loader

  @impl true
  def load(opts) do
    case Keyword.get(opts, :mode, :ok) do
      :ok ->
        {:ok,
         [
           %{
             id: "a",
             slug: "alpha",
             content: "# Alpha",
             metadata: %{published: true}
           },
           %{
             id: "b",
             slug: "beta",
             content: "# Beta",
             metadata: %{published: false}
           }
         ]}

      :error ->
        {:error, :loader_failed}
    end
  end

  @impl true
  def validate_opts(opts) do
    if Keyword.get(opts, :invalid, false) do
      {:error, "invalid fake loader config"}
    else
      :ok
    end
  end
end
