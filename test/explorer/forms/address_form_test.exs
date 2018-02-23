defmodule Explorer.AddressFormTest do
  use Explorer.DataCase

  alias Explorer.AddressForm
  alias Explorer.Credit
  alias Explorer.Debit

  describe "build/1" do
    test "returns a balance" do
      sender = insert(:address)
      recipient = insert(:address)
      transaction = insert(:transaction, value: 10)
      block = insert(:block)
      insert(:block_transaction, block: block, transaction: transaction)
      insert(:receipt, transaction: transaction, status: 1)
      insert(:from_address, address: sender, transaction: transaction)
      insert(:to_address, address: recipient, transaction: transaction)

      Credit.refresh()
      Debit.refresh()

      assert AddressForm.build(Repo.preload(recipient, [:debit, :credit])).balance ==
               Decimal.new(10)
    end

    test "returns a zero balance when the address does not have balances" do
      address = insert(:address, %{hash: "bert"})
      insert(:transaction, value: 5) |> with_addresses(%{to: "bert", from: "ernie"})
      insert(:transaction, value: 5) |> with_addresses(%{to: "bert", from: "kermit"})

      assert AddressForm.build(Repo.preload(address, [:debit, :credit])).balance == Decimal.new(0)
    end
  end
end
