defmodule Explorer.Chain.Import.Runner.AddressesTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.{Address, Wei}
  alias Explorer.Chain.Import.Runner.Addresses
  alias Explorer.Repo

  describe "run/1" do
    test "does not update fetched_coin_balance if original value is not nil but new value is nil" do
      block_number = 5
      original_address = insert(:address, fetched_coin_balance: 5, fetched_coin_balance_block_number: block_number)

      new_params = %{
        fetched_coin_balance: nil,
        fetched_coin_balance_block_number: block_number,
        hash: to_string(original_address.hash)
      }

      changeset = Address.balance_changeset(%Address{}, new_params)

      wei = original_address.fetched_coin_balance

      assert {:ok,
              %{
                addresses: [
                  %Address{
                    fetched_coin_balance: ^wei,
                    fetched_coin_balance_block_number: 5
                  }
                ]
              }} = run([changeset.changes])
    end

    test "updates fetched_coin_balance if original value is nil and new value is not nil" do
      block_number = 5
      original_address = insert(:address, fetched_coin_balance: nil, fetched_coin_balance_block_number: block_number)

      new_params = %{
        fetched_coin_balance: 5,
        fetched_coin_balance_block_number: block_number,
        hash: to_string(original_address.hash)
      }

      changeset = Address.balance_changeset(%Address{}, new_params)

      wei = %Wei{value: Decimal.new(new_params.fetched_coin_balance)}

      assert {:ok,
              %{
                addresses: [
                  %Address{
                    fetched_coin_balance: ^wei,
                    fetched_coin_balance_block_number: 5
                  }
                ]
              }} = run([changeset.changes])
    end
  end

  defp run(changes) do
    timestamp = DateTime.utc_now()
    options = %{timestamps: %{inserted_at: timestamp, updated_at: timestamp}}

    Multi.new()
    |> Addresses.run(changes, options)
    |> Repo.transaction()
  end
end
