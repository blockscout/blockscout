defmodule Explorer.Chain.ReceiptFactory do
  defmacro __using__(_opts) do
    quote do
      def receipt_factory do
        %Explorer.Chain.Receipt{
          cumulative_gas_used: Enum.random(21_000..100_000),
          gas_used: Enum.random(21_000..100_000),
          status: Enum.random(1..2),
          index: sequence("")
        }
      end
    end
  end
end
