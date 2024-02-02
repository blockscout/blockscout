defmodule Explorer.Chain.Import.Runner.Address.CurrentTokenBalancesTest do
  use Explorer.DataCase

  import Explorer.Chain.Import.RunnerCase, only: [insert_token_balance: 1, update_holder_count!: 2]

  alias Ecto.Multi
  alias Explorer.Chain.{Address, Token}
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Import.Runner.Address.CurrentTokenBalances
  alias Explorer.Repo

  describe "run/2" do
    setup do
      address = insert(:address)
      token = insert(:token, holder_count: 0)

      options = %{
        timeout: :infinity,
        timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
      }

      %{address: address, token: token, options: options}
    end

    test "inserts in the current token balances", %{
      address: %Address{hash: address_hash},
      token: %Token{contract_address_hash: token_contract_address_hash},
      options: options
    } do
      value = Decimal.new(100)
      block_number = 1

      assert {:ok,
              %{
                address_current_token_balances: [
                  %Explorer.Chain.Address.CurrentTokenBalance{
                    address_hash: ^address_hash,
                    block_number: ^block_number,
                    token_contract_address_hash: ^token_contract_address_hash,
                    value: ^value
                  }
                ],
                address_current_token_balances_update_token_holder_counts: [
                  %{
                    contract_address_hash: ^token_contract_address_hash,
                    holder_count: 1
                  }
                ]
              }} =
               run_changes(
                 %{
                   address_hash: address_hash,
                   block_number: block_number,
                   token_contract_address_hash: token_contract_address_hash,
                   value: value
                 },
                 options
               )

      current_token_balances =
        CurrentTokenBalance
        |> Repo.all()
        |> Enum.count()

      assert current_token_balances == 1
    end

    test "inserts values for multiple token IDs in the current token balances", %{
      address: %Address{hash: address_hash},
      token: %Token{contract_address_hash: token_contract_address_hash},
      options: options
    } do
      value_1 = Decimal.new(111)
      token_id_1 = Decimal.new(1)

      value_2 = Decimal.new(222)
      token_id_2 = Decimal.new(2)

      token_erc_20 = insert(:token, holder_count: 0)
      token_erc_20_contract_address_hash = token_erc_20.contract_address_hash
      value_3 = Decimal.new(333)
      token_id_3 = nil

      token_erc_721 = insert(:token, holder_count: 0)
      token_erc_721_contract_address_hash = token_erc_721.contract_address_hash
      value_4 = Decimal.new(1)
      token_id_4 = Decimal.new(1)

      value_5 = Decimal.new(2)
      token_id_5 = Decimal.new(555)

      block_number = 1

      assert {:ok,
              %{
                address_current_token_balances: [
                  %Explorer.Chain.Address.CurrentTokenBalance{
                    address_hash: ^address_hash,
                    block_number: ^block_number,
                    token_contract_address_hash: ^token_contract_address_hash,
                    value: ^value_1,
                    token_id: ^token_id_1
                  },
                  %Explorer.Chain.Address.CurrentTokenBalance{
                    address_hash: ^address_hash,
                    block_number: ^block_number,
                    token_contract_address_hash: ^token_contract_address_hash,
                    value: ^value_2,
                    token_id: ^token_id_2
                  },
                  %Explorer.Chain.Address.CurrentTokenBalance{
                    address_hash: ^address_hash,
                    block_number: ^block_number,
                    token_contract_address_hash: ^token_erc_20_contract_address_hash,
                    value: ^value_3,
                    token_id: ^token_id_3
                  },
                  %Explorer.Chain.Address.CurrentTokenBalance{
                    address_hash: ^address_hash,
                    block_number: ^block_number,
                    token_contract_address_hash: ^token_erc_721_contract_address_hash,
                    value: ^value_5,
                    token_id: nil
                  }
                ],
                address_current_token_balances_update_token_holder_counts: [
                  %{
                    contract_address_hash: ^token_contract_address_hash,
                    holder_count: 2
                  },
                  %{
                    contract_address_hash: ^token_erc_20_contract_address_hash,
                    holder_count: 1
                  },
                  %{
                    contract_address_hash: ^token_erc_721_contract_address_hash,
                    holder_count: 1
                  }
                ]
              }} =
               run_changes_list(
                 [
                   %{
                     address_hash: address_hash,
                     block_number: block_number,
                     token_contract_address_hash: token_contract_address_hash,
                     value: value_1,
                     value_fetched_at: DateTime.utc_now(),
                     token_id: token_id_1,
                     token_type: "ERC-1155"
                   },
                   %{
                     address_hash: address_hash,
                     block_number: block_number,
                     token_contract_address_hash: token_contract_address_hash,
                     value: value_2,
                     value_fetched_at: DateTime.utc_now(),
                     token_id: token_id_2,
                     token_type: "ERC-1155"
                   },
                   %{
                     address_hash: address_hash,
                     block_number: block_number,
                     token_contract_address_hash: token_erc_20.contract_address_hash,
                     value: value_3,
                     value_fetched_at: DateTime.utc_now(),
                     token_id: token_id_3,
                     token_type: "ERC-20"
                   },
                   %{
                     address_hash: address_hash,
                     block_number: block_number,
                     token_contract_address_hash: token_erc_721.contract_address_hash,
                     value: value_4,
                     value_fetched_at: DateTime.add(DateTime.utc_now(), -1),
                     token_id: token_id_4,
                     token_type: "ERC-721"
                   },
                   %{
                     address_hash: address_hash,
                     block_number: block_number,
                     token_contract_address_hash: token_erc_721.contract_address_hash,
                     value: value_5,
                     value_fetched_at: DateTime.utc_now(),
                     token_id: token_id_5,
                     token_type: "ERC-721"
                   }
                 ],
                 options
               )

      current_token_balances =
        CurrentTokenBalance
        |> Repo.all()

      current_token_balances_count =
        current_token_balances
        |> Enum.count()

      assert current_token_balances_count == 4
    end

    test "updates when the new block number is greater", %{
      address: address,
      token: token,
      options: options
    } do
      insert(
        :address_current_token_balance,
        address: address,
        block_number: 1,
        token_contract_address_hash: token.contract_address_hash,
        value: 100
      )

      run_changes(
        %{
          address_hash: address.hash,
          block_number: 2,
          token_contract_address_hash: token.contract_address_hash,
          value: Decimal.new(200)
        },
        options
      )

      current_token_balance = Repo.get_by(CurrentTokenBalance, address_hash: address.hash)

      assert current_token_balance.block_number == 2
      assert current_token_balance.value == Decimal.new(200)
    end

    test "ignores when the new block number is lesser", %{
      address: %Address{hash: address_hash} = address,
      token: %Token{contract_address_hash: token_contract_address_hash},
      options: options
    } do
      insert(
        :address_current_token_balance,
        address: address,
        block_number: 2,
        token_contract_address_hash: token_contract_address_hash,
        value: 200
      )

      update_holder_count!(token_contract_address_hash, 1)

      assert {:ok, %{address_current_token_balances: [], address_current_token_balances_update_token_holder_counts: []}} =
               run_changes(
                 %{
                   address_hash: address_hash,
                   token_contract_address_hash: token_contract_address_hash,
                   block_number: 1,
                   value: Decimal.new(100)
                 },
                 options
               )

      current_token_balance = Repo.get_by(CurrentTokenBalance, address_hash: address_hash)

      assert current_token_balance.block_number == 2
      assert current_token_balance.value == Decimal.new(200)
    end

    test "a non-holder updating to a holder increases the holder_count", %{
      address: %Address{hash: address_hash} = address,
      token: %Token{contract_address_hash: token_contract_address_hash},
      options: options
    } do
      previous_block_number = 1

      insert_token_balance(%{
        address: address,
        token_contract_address_hash: token_contract_address_hash,
        block_number: previous_block_number,
        value: 0
      })

      block_number = previous_block_number + 1
      value = Decimal.new(1)

      assert {:ok,
              %{
                address_current_token_balances: [
                  %Explorer.Chain.Address.CurrentTokenBalance{
                    address_hash: ^address_hash,
                    block_number: ^block_number,
                    token_contract_address_hash: ^token_contract_address_hash,
                    value: ^value
                  }
                ],
                address_current_token_balances_update_token_holder_counts: [
                  %{
                    contract_address_hash: ^token_contract_address_hash,
                    holder_count: 1
                  }
                ]
              }} =
               run_changes(
                 %{
                   address_hash: address_hash,
                   token_contract_address_hash: token_contract_address_hash,
                   block_number: block_number,
                   value: value
                 },
                 options
               )
    end

    test "a holder updating to a non-holder decreases the holder_count", %{
      address: %Address{hash: address_hash} = address,
      token: %Token{contract_address_hash: token_contract_address_hash},
      options: options
    } do
      previous_block_number = 1

      insert_token_balance(%{
        address: address,
        token_contract_address_hash: token_contract_address_hash,
        block_number: previous_block_number,
        value: 1
      })

      update_holder_count!(token_contract_address_hash, 1)

      block_number = previous_block_number + 1
      value = Decimal.new(0)

      assert {:ok,
              %{
                address_current_token_balances: [
                  %Explorer.Chain.Address.CurrentTokenBalance{
                    address_hash: ^address_hash,
                    block_number: ^block_number,
                    token_contract_address_hash: ^token_contract_address_hash,
                    value: ^value
                  }
                ],
                address_current_token_balances_update_token_holder_counts: [
                  %{contract_address_hash: ^token_contract_address_hash, holder_count: 0}
                ]
              }} =
               run_changes(
                 %{
                   address_hash: address_hash,
                   token_contract_address_hash: token_contract_address_hash,
                   block_number: block_number,
                   value: value
                 },
                 options
               )
    end

    test "a non-holder becoming and a holder becoming while a holder becomes a non-holder cancels out and holder_count does not change",
         %{
           address: %Address{hash: non_holder_becomes_holder_address_hash} = non_holder_becomes_holder_address,
           token: %Token{contract_address_hash: token_contract_address_hash},
           options: options
         } do
      previous_block_number = 1

      insert_token_balance(%{
        address: non_holder_becomes_holder_address,
        token_contract_address_hash: token_contract_address_hash,
        block_number: previous_block_number,
        value: 0
      })

      %Address{hash: holder_becomes_non_holder_address_hash} = holder_becomes_non_holder_address = insert(:address)

      insert_token_balance(%{
        address: holder_becomes_non_holder_address,
        token_contract_address_hash: token_contract_address_hash,
        block_number: previous_block_number,
        value: 1
      })

      update_holder_count!(token_contract_address_hash, 1)

      block_number = previous_block_number + 1
      non_holder_becomes_holder_value = Decimal.new(1)
      holder_becomes_non_holder_value = Decimal.new(0)

      assert {:ok,
              %{
                address_current_token_balances: [
                  %{
                    address_hash: ^non_holder_becomes_holder_address_hash,
                    token_contract_address_hash: ^token_contract_address_hash,
                    block_number: ^block_number,
                    value: ^non_holder_becomes_holder_value
                  },
                  %{
                    address_hash: ^holder_becomes_non_holder_address_hash,
                    token_contract_address_hash: ^token_contract_address_hash,
                    block_number: ^block_number,
                    value: ^holder_becomes_non_holder_value
                  }
                ],
                address_current_token_balances_update_token_holder_counts: []
              }} =
               run_changes_list(
                 [
                   %{
                     address_hash: non_holder_becomes_holder_address_hash,
                     token_contract_address_hash: token_contract_address_hash,
                     block_number: block_number,
                     value: non_holder_becomes_holder_value
                   },
                   %{
                     address_hash: holder_becomes_non_holder_address_hash,
                     token_contract_address_hash: token_contract_address_hash,
                     block_number: block_number,
                     value: holder_becomes_non_holder_value
                   }
                 ],
                 options
               )
    end
  end

  defp run_changes(changes, options) when is_map(changes) do
    run_changes_list([changes], options)
  end

  defp run_changes_list(changes_list, options) when is_list(changes_list) do
    Multi.new()
    |> CurrentTokenBalances.run(changes_list, options)
    |> Repo.transaction()
  end
end
