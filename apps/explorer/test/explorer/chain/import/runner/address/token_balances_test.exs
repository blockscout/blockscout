defmodule Explorer.Chain.Import.Runner.Address.TokenBalancesTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Chain.Import.Runner.Address.TokenBalances

  describe "run/2" do
    test "inserts token balance" do
      address = insert(:address)
      token = insert(:token)

      options = %{
        timeout: :infinity,
        timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
      }

      value_fetched_at = DateTime.utc_now()

      block_number = 1

      value = Decimal.new(100)

      token_contract_address_hash = token.contract_address_hash
      address_hash = address.hash

      changes = %{
        address_hash: address_hash,
        block_number: block_number,
        token_contract_address_hash: token_contract_address_hash,
        value: value,
        value_fetched_at: value_fetched_at
      }

      assert {:ok,
              %{
                address_token_balances: [
                  %TokenBalance{
                    address_hash: address_hash,
                    block_number: ^block_number,
                    token_contract_address_hash: ^token_contract_address_hash,
                    value: ^value,
                    value_fetched_at: ^value_fetched_at
                  }
                ]
              }} = run_changes(changes, options)
    end

    test "does not nillifies existing value" do
      address = insert(:address)
      token = insert(:token)

      options = %{
        timeout: :infinity,
        timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
      }

      value_fetched_at = DateTime.utc_now()

      block_number = 1

      value = Decimal.new(100)

      token_contract_address_hash = token.contract_address_hash
      address_hash = address.hash

      changes = %{
        address_hash: address_hash,
        block_number: block_number,
        token_contract_address_hash: token_contract_address_hash,
        value: nil,
        value_fetched_at: value_fetched_at
      }

      assert {:ok,
              %{
                address_token_balances: [
                  %TokenBalance{
                    address_hash: address_hash,
                    block_number: ^block_number,
                    token_contract_address_hash: ^token_contract_address_hash,
                    value: nil,
                    value_fetched_at: ^value_fetched_at
                  }
                ]
              }} = run_changes(changes, options)

      new_changes = %{
        address_hash: address_hash,
        block_number: block_number,
        token_contract_address_hash: token_contract_address_hash,
        value: value,
        value_fetched_at: DateTime.utc_now()
      }

      run_changes(new_changes, options)
    end
  end

  defp run_changes(changes, options) when is_map(changes) do
    run_changes_list([changes], options)
  end

  defp run_changes_list(changes_list, options) when is_list(changes_list) do
    Multi.new()
    |> TokenBalances.run(changes_list, options)
    |> Repo.transaction()
  end
end
