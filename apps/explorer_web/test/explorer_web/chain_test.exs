defmodule ExplorerWeb.ChainTest do
  use Explorer.DataCase

  alias Explorer.Chain.{Address, Block, Transaction}
  alias ExplorerWeb.Chain

  describe "from_param/1" do
    test "finds a block by block number with a valid block number" do
      %Block{number: number} = insert(:block, number: 37)

      assert {:ok, %Block{number: ^number}} =
               number
               |> to_string()
               |> Chain.from_param()
    end

    test "finds a transaction by hash" do
      %Transaction{hash: hash} = insert(:transaction)

      assert {:ok, %Transaction{hash: ^hash}} = Chain.from_param(hash)
    end

    test "finds an address by hash" do
      %Address{hash: hash} = insert(:address)

      assert {:ok, %Address{hash: ^hash}} = Chain.from_param(hash)
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
end
