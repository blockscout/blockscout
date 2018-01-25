defmodule Explorer.TransactionFactory do
  defmacro __using__(_opts) do
    quote do
      def transaction_factory do
        %Explorer.Transaction{
          block: build(:block),
          hash: sequence("0x"),
          value: Enum.random(1..100_000),
        }
      end
    end
  end
end
