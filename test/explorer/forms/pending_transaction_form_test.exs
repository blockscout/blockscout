defmodule Explorer.PendingTransactionFormTest do
  use Explorer.DataCase

  alias Explorer.PendingTransactionForm

  describe "build/1" do
    test "returns a successful transaction when there is a successful receipt" do
      time = DateTime.utc_now()
      to_address = insert(:address, hash: "0xcafe")
      from_address = insert(:address, hash: "0xbee5")
      transaction = insert(:transaction, inserted_at: time, updated_at: time)
      insert(:to_address, address: to_address, transaction: transaction)
      insert(:from_address, address: from_address, transaction: transaction)
      form = PendingTransactionForm.build(transaction |> Repo.preload([:to_address, :from_address]))
      assert(form == Map.merge(transaction |> Repo.preload([:to_address, :from_address]), %{
        to_address_hash: "0xcafe",
        from_address_hash: "0xbee5",
        first_seen: time |> Timex.from_now(),
        last_seen: time |> Timex.from_now(),
      }))
    end
  end
end
