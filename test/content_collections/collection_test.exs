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

  defmodule CountingLoader do
    @behaviour ContentCollections.Loader

    @impl true
    def load(_opts) do
      Process.put(:counting_loader_calls, Process.get(:counting_loader_calls, 0) + 1)

      {:ok,
       [
         %{id: "1", slug: "one", content: "# One", metadata: %{published: true}},
         %{id: "2", slug: "two", content: "# Two", metadata: %{published: false}}
       ]}
    end
  end

  defmodule RuntimeCachedCollection do
    use ContentCollections.Collection,
      name: :runtime_cached_collection,
      loader: {CountingLoader, []},
      compile_time: false,
      cache: true
  end

  defmodule RuntimeNoCacheCollection do
    use ContentCollections.Collection,
      name: :runtime_no_cache_collection,
      loader: {CountingLoader, []},
      compile_time: false,
      cache: false
  end

  setup do
    Process.delete(:counting_loader_calls)
    :persistent_term.erase(RuntimeCollection.__cache_key__())
    :persistent_term.erase(RuntimeCachedCollection.__cache_key__())
    :persistent_term.erase(RuntimeNoCacheCollection.__cache_key__())
    :ok
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

  test "runtime cache loads once when cache is enabled" do
    assert Process.get(:counting_loader_calls, 0) == 0

    assert length(RuntimeCachedCollection.all()) == 2
    assert length(RuntimeCachedCollection.all()) == 2

    assert Process.get(:counting_loader_calls, 0) == 1
  end

  test "runtime cache can be bypassed when disabled" do
    assert Process.get(:counting_loader_calls, 0) == 0

    assert length(RuntimeNoCacheCollection.all()) == 2
    assert length(RuntimeNoCacheCollection.all()) == 2

    assert Process.get(:counting_loader_calls, 0) == 2
  end

  test "reload invalidates runtime cache and repopulates entries" do
    assert length(RuntimeCachedCollection.all()) == 2
    assert Process.get(:counting_loader_calls, 0) == 1

    assert {:ok, entries} = RuntimeCachedCollection.reload()
    assert length(entries) == 2
    assert Process.get(:counting_loader_calls, 0) == 2

    assert length(RuntimeCachedCollection.all()) == 2
    assert Process.get(:counting_loader_calls, 0) == 2
  end
end
