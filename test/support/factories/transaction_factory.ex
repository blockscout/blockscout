defmodule Explorer.TransactionFactory do
  defmacro __using__(_opts) do
    quote do
      alias Explorer.Address
      alias Explorer.BlockTransaction
      alias Explorer.Repo

      def transaction_factory do
        %Explorer.Transaction{
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
        }
      end

      def with_addresses(transaction, %{to: to, from: from} \\ %{to: nil, from: nil}) do
        to_address = if to, do: Repo.get_by(Address, %{hash: to}) || insert(:address, hash: to), else: insert(:address)
        from_address = if from, do: Repo.get_by(Address, %{hash: from}) ||insert(:address, hash: from), else: insert(:address)
        insert(:to_address, %{transaction_id: transaction.id, address_id: to_address.id})
        insert(:from_address, %{transaction_id: transaction.id, address_id: from_address.id})
        transaction
      end

      def with_block(transaction, block \\ nil) do
        block = block || insert(:block)
        insert(:block_transaction, %{block_id: block.id, transaction_id: transaction.id})
        transaction
      end

      def list_with_block(transactions, block \\ nil) do
        Enum.map(transactions, fn(transaction) -> with_block(transaction, block) end)
      end
    end
  end
end
