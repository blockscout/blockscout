defmodule Explorer.BlockTransactionFactory do
  defmacro __using__(_opts) do
    quote do
      def block_transaction_factory do
        %Explorer.BlockTransaction{}
      end
    end
  end
end
