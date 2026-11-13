# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.JSONValueTest do
  use ExUnit.Case, async: true

  alias Explorer.Chain.JSONValue

  doctest JSONValue

  describe "cast/1" do
    test "accepts an empty list" do
      assert JSONValue.cast([]) == {:ok, []}
    end

    test "accepts a list of objects" do
      value = [%{"type" => "0x1", "target" => "0x0000000000000000000000000000000000000001"}]

      assert JSONValue.cast(value) == {:ok, value}
    end

    test "accepts a list of hex strings" do
      value = ["0xd60194000000000000000000000000000000000000000001"]

      assert JSONValue.cast(value) == {:ok, value}
    end

    test "accepts nested lists" do
      value = [["0x01", ["0x02", 3]], [true, nil]]

      assert JSONValue.cast(value) == {:ok, value}
    end

    test "accepts an object and scalar values" do
      assert JSONValue.cast(%{"key" => [1, 2.5]}) == {:ok, %{"key" => [1, 2.5]}}
      assert JSONValue.cast("0x") == {:ok, "0x"}
      assert JSONValue.cast(1) == {:ok, 1}
    end

    test "rejects terms without a JSON representation" do
      assert JSONValue.cast({:a, 1}) == :error
      assert JSONValue.cast([self()]) == :error
      assert JSONValue.cast(%{key: "value"}) == :error
      assert JSONValue.cast(~D[2026-01-01]) == :error
    end
  end

  describe "dump/1 and load/1" do
    test "keep the value without change" do
      value = [%{"type" => "0x1"}, "0x01", [1]]

      assert JSONValue.dump(value) == {:ok, value}
      assert JSONValue.load(value) == {:ok, value}
    end

    test "dump rejects terms without a JSON representation" do
      assert JSONValue.dump({:a, 1}) == :error
    end
  end
end
