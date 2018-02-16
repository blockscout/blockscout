defmodule Explorer.AddressFormTest do
  use Explorer.DataCase

  alias Explorer.AddressForm
  alias Explorer.Credit
  alias Explorer.Debit

  describe "build/1" do
    test "that it has a balance" do
      address = insert(:address, %{hash: "bert"})
      insert(:transaction, value: 5) |> with_addresses(%{to: "bert", from: "ernie"})
      insert(:transaction, value: 5) |> with_addresses(%{to: "bert", from: "kermit"})

      Credit.refresh
      Debit.refresh
      assert AddressForm.build(Repo.preload(address, [:debit, :credit])).balance == Decimal.new(10)
    end
  end
end
