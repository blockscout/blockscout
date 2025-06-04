defmodule Indexer.Transform.Celo.ValidatorEpochPaymentDistributionsTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  alias Explorer.Chain.Hash
  alias Indexer.Transform.Celo.ValidatorEpochPaymentDistributions

  describe "parse/1" do
    setup do
      old_env = Application.get_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts, [])

      validator = insert(:address)

      Application.put_env(
        :explorer,
        Explorer.Chain.Cache.CeloCoreContracts,
        Keyword.merge(old_env,
          contracts: %{
            "addresses" => %{
              "Validators" => [
                %{"address" => to_string(validator.hash), "updated_at_block_number" => 0}
              ]
            }
          }
        )
      )

      on_exit(fn -> Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts, old_env) end)

      %{validator: validator}
    end

    test "parses log", %{validator: validator} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      log =
        insert(:log,
          transaction_hash: transaction.hash,
          transaction: transaction,
          address_hash: validator.hash,
          address: validator,
          first_topic: ValidatorEpochPaymentDistributions.signature(),
          second_topic: "0x0000000000000000000000003078323232323232323232323232323232323232",
          third_topic: "0x0000000000000000000000003078333333333333333333333333333333333333",
          data: "0x" <> Base.encode16(ABI.encode("(uint256,uint256)", [{123, 456}]), case: :lower)
        )

      logs = [log]

      assert [
               %{
                 group_address: %Hash{
                   byte_count: 20,
                   bytes: "3078333333333333333333333333333333333333" |> Base.decode16!(case: :lower)
                 },
                 group_payment: 456,
                 validator_address: %Hash{
                   byte_count: 20,
                   bytes: "3078323232323232323232323232323232323232" |> Base.decode16!(case: :lower)
                 },
                 validator_payment: 123
               }
             ] == ValidatorEpochPaymentDistributions.parse(logs)
    end
  end
end
