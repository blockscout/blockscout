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
        value_fetched_at: value_fetched_at,
        token_id: 11,
        token_type: "ERC-20"
      }

      assert {:ok,
              %{
                address_token_balances: [
                  %TokenBalance{
                    address_hash: ^address_hash,
                    block_number: ^block_number,
                    token_contract_address_hash: ^token_contract_address_hash,
                    token_id: nil,
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
        value_fetched_at: value_fetched_at,
        token_id: nil,
        token_type: "ERC-20"
      }

      assert {:ok,
              %{
                address_token_balances: [
                  %TokenBalance{
                    address_hash: address_hash,
                    block_number: ^block_number,
                    token_contract_address_hash: ^token_contract_address_hash,
                    token_id: nil,
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

  test "does not nillifies existing value ERC-1155" do
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
      value_fetched_at: value_fetched_at,
      token_id: 11,
      token_type: "ERC-1155"
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

  test "set value_fetched_at to null for existing record if incoming data has this field empty" do
    address = insert(:address)
    token = insert(:token)

    options = %{
      timeout: :infinity,
      timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
    }

    block_number = 1

    value = Decimal.new(100)
    value_fetched_at = DateTime.utc_now()

    token_contract_address_hash = token.contract_address_hash
    address_hash = address.hash

    first_changes = %{
      address_hash: address_hash,
      block_number: block_number,
      token_contract_address_hash: token_contract_address_hash,
      token_id: 11,
      token_type: "ERC-721",
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
                  token_id: nil,
                  value: ^value,
                  value_fetched_at: ^value_fetched_at
                }
              ]
            }} = run_changes(first_changes, options)

    second_changes = %{
      address_hash: address_hash,
      block_number: block_number,
      token_contract_address_hash: token_contract_address_hash,
      token_id: 12,
      token_type: "ERC-721"
    }

    assert {:ok,
            %{
              address_token_balances: [
                %TokenBalance{
                  address_hash: ^address_hash,
                  block_number: ^block_number,
                  token_contract_address_hash: ^token_contract_address_hash,
                  token_id: nil,
                  value: ^value,
                  value_fetched_at: nil
                }
              ]
            }} = run_changes(second_changes, options)
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
