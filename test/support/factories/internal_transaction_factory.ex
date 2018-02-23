defmodule Explorer.InternalTransactionFactory do
  defmacro __using__(_opts) do
    quote do
      def internal_transaction_factory do
        %Explorer.InternalTransaction{
          index: Enum.random(0..9),
          call_type: Enum.random(["call", "creates", "calldelegate"]),
          trace_address: [Enum.random(0..4), Enum.random(0..4)],
          from_address_id: insert(:address).id,
          to_address_id: insert(:address).id,
          transaction_id: insert(:transaction).id,
          value: Enum.random(1..100_000),
          gas: Enum.random(1..100_000),
          gas_used: Enum.random(1..100_000),
          input: sequence("0x"),
          output: sequence("0x")
        }
      end
    end
  end
end
