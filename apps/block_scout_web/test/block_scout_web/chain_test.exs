defmodule BlockScoutWeb.ChainTest do
  use Explorer.DataCase

  alias Explorer.Chain.{Address, Block, Transaction}
  alias BlockScoutWeb.Chain

  describe "current_filter/1" do
    test "sets direction based on to filter" do
      assert [direction: :to] = Chain.current_filter(%{"filter" => "to"})
    end

    test "sets direction based on from filter" do
      assert [direction: :from] = Chain.current_filter(%{"filter" => "from"})
    end

    test "no direction set" do
      assert [] = Chain.current_filter(%{})
    end

    test "no direction set with paging_options" do
      assert [paging_options: "test"] = Chain.current_filter(%{paging_options: "test"})
    end
  end

  describe "from_param/1" do
    test "finds a block by block number with a valid block number" do
      %Block{number: number} = insert(:block, number: 37)

      assert {:ok, %Block{number: ^number}} =
               number
               |> to_string()
               |> Chain.from_param()
    end

    test "finds a transaction by hash string" do
      transaction = %Transaction{hash: hash} = insert(:transaction)

      assert {:ok, %Transaction{hash: ^hash}} = transaction |> Phoenix.Param.to_param() |> Chain.from_param()
    end

    test "finds an address by hash string" do
      address = %Address{hash: hash} = insert(:address)

      assert {:ok, %Address{hash: ^hash}} = address |> Phoenix.Param.to_param() |> Chain.from_param()
    end

    test "finds a token by its name" do
      name = "AYR"
      insert(:token, symbol: name)

      assert {:ok, %Address{}} = name |> Chain.from_param()
    end

    test "finds a token by its name even if lowercase name was passed" do
      name = "ayr"
      insert(:token, symbol: String.upcase(name))

      assert {:ok, %Address{}} = name |> Chain.from_param()
    end

    test "returns {:error, :not_found} when garbage is passed in" do
      assert {:error, :not_found} = Chain.from_param("any ol' thing")
    end

    test "returns {:error, :not_found} when it does not find a match" do
      transaction_hash = String.pad_trailing("0xnonsense", 43, "0")
      address_hash = String.pad_trailing("0xbaddress", 42, "0")

      assert {:error, :not_found} = Chain.from_param("38999")
      assert {:error, :not_found} = Chain.from_param(transaction_hash)
      assert {:error, :not_found} = Chain.from_param(address_hash)
    end
  end

  describe "Posion.encode!" do
    test "correctly encodes decimal values" do
      val = Decimal.from_float(5.55)

      assert "5.55" == Poison.encode!(val)
    end
  end
end
