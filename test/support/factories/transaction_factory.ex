defmodule Explorer.TransactionFactory do
  defmacro __using__(_opts) do
    quote do
      def transaction_factory do
        %Explorer.Transaction{
          block: build(:block),
          hash: sequence("0x"),
          value: Enum.random(1..100_000),
          gas: Enum.random(21_000..100_000),
          gas_price: Enum.random(1..100_000),
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
    end
  end
end
