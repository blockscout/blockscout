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

  test "keeps the value of a converted balance and the ERC-404 type on legacy updates of it" do
    address = insert(:address)
    token = insert(:token, type: "ERC-721")

    options = %{
      timeout: :infinity,
      timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
    }

    fetched_at = DateTime.add(DateTime.utc_now(), -60)

    legacy_changes = %{
      address_hash: address.hash,
      block_number: 1,
      token_contract_address_hash: token.contract_address_hash,
      value: Decimal.new(2),
      value_fetched_at: fetched_at,
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

    # `balanceOf(address)` gives the same fungible balance for the legacy types
    assert %TokenBalance{token_type: "ERC-404", value: value, value_fetched_at: ^fetched_at} =
             Repo.get_by(TokenBalance, address_hash: address.hash)

    assert Decimal.equal?(value, 2)

    # the token balance fetcher may still update the balance with the type it
    # read before the conversion; the value is the same `balanceOf(address)` one
    for {legacy_type, legacy_value} <- [{"ERC-721", 3}, {"ERC-20", 4}] do
      assert {:ok, _} =
               run_changes(
                 %{
                   legacy_changes
                   | token_type: legacy_type,
                     value: Decimal.new(legacy_value),
                     value_fetched_at: DateTime.utc_now()
                 },
                 options
               )

      assert %TokenBalance{token_type: "ERC-404", token_id: nil, value: value} =
               Repo.get_by(TokenBalance, address_hash: address.hash)

      assert Decimal.equal?(value, legacy_value)
    end

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

  test "gives the ERC-404 type to new legacy balances of a token retyped to ERC-404" do
    address = insert(:address)
    token = insert(:token, type: "ERC-404")

    options = %{
      timeout: :infinity,
      timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
    }

    # the block fetcher read the token as an ERC-721 one before it was retyped
    changes_list =
      for {legacy_type, block_number} <- [{"ERC-721", 1}, {"ERC-20", 2}] do
        %{
          address_hash: address.hash,
          block_number: block_number,
          token_contract_address_hash: token.contract_address_hash,
          token_id: 5,
          token_type: legacy_type
        }
      end

    assert {:ok, _} = run_changes_list(changes_list, options)

    assert [
             %TokenBalance{block_number: 1, token_type: "ERC-404", token_id: nil},
             %TokenBalance{block_number: 2, token_type: "ERC-404", token_id: nil}
           ] = Repo.all(from(tb in TokenBalance, order_by: tb.block_number))
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
