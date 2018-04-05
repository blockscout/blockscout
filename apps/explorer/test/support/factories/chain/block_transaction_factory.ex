defmodule Explorer.Chain.BlockTransactionFactory do
  defmacro __using__(_opts) do
    quote do
      def block_transaction_factory do
        %Explorer.Chain.BlockTransaction{}
      end
    end
  end
end
