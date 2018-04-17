defmodule Explorer.Chain.TransactionFactory do
  defmacro __using__(_opts) do
    quote do
      alias Explorer.Chain.{Address, BlockTransaction, Transaction}
      alias Explorer.Repo

      def transaction_factory do
        %Transaction{
          hash: String.pad_trailing(sequence("0x"), 43, "action"),
          value: Enum.random(1..100_000),
          gas: Enum.random(21_000..100_000),
          gas_price: Enum.random(10..99) * 1_000_000_00,
          input: sequence("0x"),
          nonce: Enum.random(1..1_000),
          public_key: sequence("0x"),
          r: sequence("0x"),
          s: sequence("0x"),
          standard_v: sequence("0x"),
          transaction_index: sequence("0x"),
          v: sequence("0x"),
          to_address_id: insert(:address).id,
          from_address_id: insert(:address).id
        }
      end

      def with_block(transaction, block \\ nil) do
        block = block || insert(:block)
        insert(:block_transaction, %{block_id: block.id, transaction_id: transaction.id})
        transaction
      end

      def list_with_block(transactions, block \\ nil) do
        Enum.map(transactions, fn transaction -> with_block(transaction, block) end)
      end
    end
  end
end
