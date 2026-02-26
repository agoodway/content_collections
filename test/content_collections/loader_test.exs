defmodule ContentCollections.LoaderTest do
  use ExUnit.Case, async: true

  alias ContentCollections.Loader
  alias ContentCollections.TestSupport.FakeLoader

  defmodule LoaderWithoutValidate do
    @behaviour ContentCollections.Loader

    @impl true
    def load(_opts), do: {:ok, []}
  end

  test "normalize/1 accepts module and tuple" do
    assert Loader.normalize(FakeLoader) == {FakeLoader, []}
    assert Loader.normalize({FakeLoader, mode: :ok}) == {FakeLoader, mode: :ok}
  end

  test "normalize/1 raises for invalid loader spec" do
    assert_raise ArgumentError, ~r/Invalid loader specification/, fn ->
      Loader.normalize({"bad", []})
    end
  end

  test "validate_opts/2 calls callback when present" do
    assert Loader.validate_opts(FakeLoader, invalid: true) ==
             {:error, "invalid fake loader config"}

    assert Loader.validate_opts(FakeLoader, invalid: false) == :ok
  end

  test "validate_opts/2 returns :ok when callback is absent" do
    assert Loader.validate_opts(LoaderWithoutValidate, anything: true) == :ok
  end
end
