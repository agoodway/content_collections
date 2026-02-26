defmodule ContentCollections.CollectionTest do
  use ExUnit.Case, async: true

  alias ContentCollections.TestSupport.FakeLoader

  defmodule RuntimeCollection do
    use ContentCollections.Collection,
      name: :runtime_collection,
      loader: {FakeLoader, mode: :ok},
      compile_time: false
  end

  defmodule CompileTimeCollection do
    use ContentCollections.Collection,
      name: :compile_time_collection,
      loader: {FakeLoader, mode: :ok},
      compile_time: true
  end

  test "runtime collection query API works" do
    entries = RuntimeCollection.all()
    assert length(entries) == 2

    assert RuntimeCollection.get("a").slug == "alpha"
    assert RuntimeCollection.get_by_slug("beta").id == "b"
    assert RuntimeCollection.filter(& &1.metadata.published) |> length() == 1
    assert RuntimeCollection.find(&(&1.id == "b")).slug == "beta"
    assert RuntimeCollection.count() == 2
    assert RuntimeCollection.exists?("a")
    assert RuntimeCollection.exists?("missing") == false
    assert {:ok, reloaded} = RuntimeCollection.reload()
    assert length(reloaded) == 2
  end

  test "compile-time collection query API works" do
    entries = CompileTimeCollection.all()
    assert length(entries) == 2

    assert CompileTimeCollection.get("a").slug == "alpha"
    assert CompileTimeCollection.get_by_slug("beta").id == "b"
    assert {:error, :compile_time_collection} = CompileTimeCollection.reload()
  end

  test "invalid loader config raises at compile-time" do
    assert_raise RuntimeError, ~r/Invalid loader configuration/, fn ->
      defmodule InvalidLoaderConfigCollection do
        use ContentCollections.Collection,
          loader: {FakeLoader, invalid: true},
          compile_time: false
      end
    end
  end

  test "loader failures raise when loading entries" do
    assert_raise RuntimeError, ~r/Failed to load content/, fn ->
      defmodule ErrorLoaderCollection do
        use ContentCollections.Collection,
          loader: {FakeLoader, mode: :error},
          compile_time: false
      end

      ErrorLoaderCollection.all()
    end
  end
end
