defmodule ContentCollectionsTest do
  use ExUnit.Case
  doctest ContentCollections

  test "delegates __using__/1 to ContentCollections.Collection" do
    assert macro_exported?(ContentCollections, :__using__, 1)
  end
end
