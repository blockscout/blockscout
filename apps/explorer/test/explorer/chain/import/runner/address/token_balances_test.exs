# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.Address.TokenBalancesTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Chain.Import.Runner.Address.TokenBalances
  alias Explorer.Chain.Token.Erc404

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

  test "filters out changes with tokens that doesn't implement balanceOf function" do
    address = insert(:address)
    token = insert(:token)

    options = %{
      timeout: :infinity,
      timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
    }

    block_number = 1
    next_block_number = block_number + 1
    token_contract_address_hash = token.contract_address_hash

    insert(:missing_balance_of_token,
      token_contract_address_hash: token_contract_address_hash,
      block_number: block_number,
      currently_implemented: true
    )

    address_hash = address.hash

    changes_list = [
      %{
        address_hash: address_hash,
        block_number: block_number,
        token_contract_address_hash: token_contract_address_hash,
        token_id: 11,
        token_type: "ERC-721"
      },
      %{
        address_hash: address_hash,
        block_number: next_block_number,
        token_contract_address_hash: token_contract_address_hash,
        token_id: 12,
        token_type: "ERC-721"
      }
    ]

    assert {:ok, %{address_token_balances: [%{block_number: ^next_block_number}]}} =
             run_changes_list(changes_list, options)
  end

  test "rejects legacy balances imported for a converted balance, which stays eligible for the refetch" do
    address = insert(:address)
    token = insert(:token, type: "ERC-721")

    options = %{
      timeout: :infinity,
      timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
    }

    legacy_changes = %{
      address_hash: address.hash,
      block_number: 1,
      token_contract_address_hash: token.contract_address_hash,
      value: nil,
      value_fetched_at: nil,
      token_id: nil,
      token_type: "ERC-721"
    }

    insert(:token_transfer,
      from_address: insert(:address),
      to_address: address,
      token_contract_address: Repo.preload(token, :contract_address).contract_address,
      block_number: 1,
      token_type: "ERC-721",
      amount: nil,
      token_ids: [1]
    )

    assert {:ok, _} = run_changes(legacy_changes, options)

    Erc404.convert(token.contract_address_hash)

    assert %TokenBalance{token_type: "ERC-404"} = Repo.get_by(TokenBalance, address_hash: address.hash)

    for legacy_type <- ["ERC-721", "ERC-20"] do
      # a placeholder and a value fetched for the legacy type
      for legacy_value <- [{nil, nil}, {Decimal.new(3), DateTime.utc_now()}] do
        {value, value_fetched_at} = legacy_value

        assert {:ok, _} =
                 run_changes(
                   %{legacy_changes | token_type: legacy_type, value: value, value_fetched_at: value_fetched_at},
                   options
                 )

        assert %TokenBalance{token_type: "ERC-404", value: nil, value_fetched_at: nil} =
                 Repo.get_by(TokenBalance, address_hash: address.hash)
      end
    end

    assert [%{address_hash: address_hash}] = TokenBalance.unfetched_token_balances() |> Repo.all()
    assert address_hash == address.hash

    # the value fetched for the ERC-404 type replaces the converted balance; the
    # changeset drops the nil token id of a fungible balance
    value_fetched_at = DateTime.utc_now()

    assert {:ok, _} =
             run_changes(
               legacy_changes
               |> Map.delete(:token_id)
               |> Map.merge(%{token_type: "ERC-404", value: Decimal.new(5), value_fetched_at: value_fetched_at}),
               options
             )

    assert %TokenBalance{token_type: "ERC-404", value: value, value_fetched_at: ^value_fetched_at} =
             Repo.get_by(TokenBalance, address_hash: address.hash)

    assert Decimal.equal?(value, 5)
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
