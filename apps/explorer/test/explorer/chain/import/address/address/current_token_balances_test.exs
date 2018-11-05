defmodule Explorer.Chain.Import.Address.CurrentTokenBalancesTest do
  use Explorer.DataCase

  alias Explorer.Chain.Import.Address.CurrentTokenBalances

  alias Explorer.Chain.{Address.CurrentTokenBalance}

  describe "insert/2" do
    setup do
      address = insert(:address, hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca")
      token = insert(:token)

      insert_options = %{
        timeout: :infinity,
        timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
      }

      %{address: address, token: token, insert_options: insert_options}
    end

    test "inserts in the current token balances", %{address: address, token: token, insert_options: insert_options} do
      changes = [
        %{
          address_hash: address.hash,
          block_number: 1,
          token_contract_address_hash: token.contract_address_hash,
          value: Decimal.new(100)
        }
      ]

      CurrentTokenBalances.insert(changes, insert_options)

      current_token_balances =
        CurrentTokenBalance
        |> Explorer.Repo.all()
        |> Enum.count()

      assert current_token_balances == 1
    end

    test "considers the last block upserting", %{address: address, token: token, insert_options: insert_options} do
      insert(
        :address_current_token_balance,
        address: address,
        block_number: 1,
        token_contract_address_hash: token.contract_address_hash,
        value: 100
      )

      changes = [
        %{
          address_hash: address.hash,
          block_number: 2,
          token_contract_address_hash: token.contract_address_hash,
          value: Decimal.new(200)
        }
      ]

      CurrentTokenBalances.insert(changes, insert_options)

      current_token_balance = Explorer.Repo.get_by(CurrentTokenBalance, address_hash: address.hash)

      assert current_token_balance.block_number == 2
      assert current_token_balance.value == Decimal.new(200)
    end

    test "considers the last block when there are duplicated params", %{
      address: address,
      token: token,
      insert_options: insert_options
    } do
      changes = [
        %{
          address_hash: address.hash,
          block_number: 4,
          token_contract_address_hash: token.contract_address_hash,
          value: Decimal.new(200)
        },
        %{
          address_hash: address.hash,
          block_number: 1,
          token_contract_address_hash: token.contract_address_hash,
          value: Decimal.new(100)
        }
      ]

      CurrentTokenBalances.insert(changes, insert_options)

      current_token_balance = Explorer.Repo.get_by(CurrentTokenBalance, address_hash: address.hash)

      assert current_token_balance.block_number == 4
      assert current_token_balance.value == Decimal.new(200)
    end
  end
end
