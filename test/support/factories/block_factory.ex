defmodule Explorer.BlockFactory do
  defmacro __using__(_opts) do
    quote do
      def block_factory do
        %Explorer.Block{
          number: 1,
          hash: "0x0",
          parent_hash: "0x0",
          nonce: "1",
          miner: "0x0",
          difficulty: 1,
          total_difficulty: 1,
          size: 0,
          gas_limit: 0,
          gas_used: 0,
          timestamp: DateTime.utc_now,
        }
      end
    end
  end
end
