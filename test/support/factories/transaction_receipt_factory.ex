defmodule Explorer.TransactionReceiptFactory do
  defmacro __using__(_opts) do
    quote do
      def transaction_receipt_factory do
        %Explorer.TransactionReceipt{
          cumulative_gas_used: Enum.random(21_000..100_000),
          gas_used: Enum.random(21_000..100_000),
          status: Enum.random(1..2),
          index: sequence(""),
        }
      end
    end
  end
end
