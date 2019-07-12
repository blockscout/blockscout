defmodule Explorer.Chain.Cache.BlockNumberTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.BlockNumber

  setup do
    Application.put_env(:explorer, Explorer.Chain.Cache.BlockNumber, enabled: true)

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.Chain.Cache.BlockNumber, enabled: false)
    end)
  end

  describe "max_number/1" do
    test "returns max number" do
      insert(:block, number: 5)

      BlockNumber.setup()

      assert BlockNumber.max_number() == 5
    end
  end

  describe "min_number/1" do
    test "returns max number" do
      insert(:block, number: 2)

      BlockNumber.setup()

      assert BlockNumber.max_number() == 2
    end
  end

  describe "update/1" do
    test "updates max number" do
      insert(:block, number: 2)

      BlockNumber.setup()

      assert BlockNumber.max_number() == 2

      assert BlockNumber.update(3)

      assert BlockNumber.max_number() == 3
    end

    test "updates min number" do
      insert(:block, number: 2)

      BlockNumber.setup()

      assert BlockNumber.min_number() == 2

      assert BlockNumber.update(1)

      assert BlockNumber.min_number() == 1
    end
  end
end
