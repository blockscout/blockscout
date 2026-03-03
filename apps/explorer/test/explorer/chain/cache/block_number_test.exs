defmodule Explorer.Chain.Cache.BlockNumberTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.BlockNumber

  setup do
    Application.put_env(:explorer, Explorer.Chain.Cache.BlockNumber, enabled: true)

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.Chain.Cache.BlockNumber, enabled: false)
    end)
  end

  describe "get_max/0" do
    test "returns max number" do
      insert(:block, number: 5)

      assert BlockNumber.get_max() == 5
    end
  end

  describe "get_min/0" do
    test "returns min number" do
      insert(:block, number: 2)

      assert BlockNumber.get_min() == 2
    end
  end

  describe "get_all/0" do
    test "returns min and max number" do
      insert(:block, number: 6)

      assert BlockNumber.get_all() == %{min: 6, max: 6}
    end
  end

  describe "update_all/1" do
    test "updates max number" do
      insert(:block, number: 2)

      assert BlockNumber.get_max() == 2

      assert BlockNumber.update_all(3)

      assert BlockNumber.get_max() == 3
    end

    test "updates min number" do
      insert(:block, number: 2)

      assert BlockNumber.get_min() == 2

      assert BlockNumber.update_all(1)

      assert BlockNumber.get_min() == 1
    end

    test "updates min and number" do
      insert(:block, number: 2)

      assert BlockNumber.get_all() == %{min: 2, max: 2}

      assert BlockNumber.update_all(1)

      assert BlockNumber.get_all() == %{min: 1, max: 2}

      assert BlockNumber.update_all(6)

      assert BlockNumber.get_all() == %{min: 1, max: 6}
    end
  end
end
