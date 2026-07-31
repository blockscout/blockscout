# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.compile_env(:explorer, :chain_type) == :eden do
  defmodule Explorer.Chain.Import.Runner.Eden.TransactionsTest do
    use Explorer.DataCase

    alias Ecto.Multi
    alias Explorer.Chain.Import.Runner.Transactions
    alias Explorer.Chain.{Transaction, Wei}

    @calls [
      %{"to" => "0x11f60a633dd30a8d1a26dd6e20167a9293fb4647", "value" => 1, "input" => "0xdeadbeef"},
      %{"to" => nil, "value" => 2, "input" => "0xc0ffee"}
    ]

    describe "run/1" do
      test "imports the Eden sponsored transaction fields" do
        fee_payer = insert(:address)
        params = sponsored_transaction_params(%{fee_payer_address_hash: fee_payer.hash, calls: @calls})

        assert {:ok, _} = run_transactions([params])

        imported = Repo.get(Transaction, params.hash)

        assert imported.type == 118
        assert imported.fee_payer_address_hash == fee_payer.hash
        assert imported.calls == @calls
      end

      test "updates the Eden sponsored transaction fields on conflict" do
        fee_payer = insert(:address)
        transaction = insert(:transaction, type: 118)

        params =
          sponsored_transaction_params(%{
            hash: transaction.hash,
            from_address_hash: transaction.from_address.hash,
            to_address_hash: transaction.to_address.hash,
            fee_payer_address_hash: fee_payer.hash,
            calls: @calls
          })

        assert {:ok, _} = run_transactions([params])

        imported = Repo.get(Transaction, transaction.hash)

        assert imported.fee_payer_address_hash == fee_payer.hash
        assert imported.calls == @calls
      end

      test "leaves the fields empty for the regular transactions" do
        params = sponsored_transaction_params(%{type: 2})

        assert {:ok, _} = run_transactions([params])

        assert %Transaction{fee_payer_address_hash: nil, calls: nil} = Repo.get(Transaction, params.hash)
      end
    end

    defp sponsored_transaction_params(overrides) do
      Map.merge(
        %{
          from_address_hash: insert(:address).hash,
          to_address_hash: insert(:address).hash,
          gas: Decimal.new(42_000),
          gas_price: %Wei{value: Decimal.new(7)},
          hash: transaction_hash(),
          input: transaction_input(),
          nonce: 1,
          r: Decimal.new(1),
          s: Decimal.new(2),
          v: Decimal.new(0),
          value: %Wei{value: Decimal.new(3)},
          type: 118
        },
        overrides
      )
    end

    defp run_transactions(changes_list) when is_list(changes_list) do
      Multi.new()
      |> Transactions.run(changes_list, %{
        timeout: :infinity,
        timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
      })
      |> Repo.transaction()
    end
  end
end
