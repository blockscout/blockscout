defmodule Explorer.BlockFactory do
  defmacro __using__(_opts) do
    quote do
      def block_factory do
        %Explorer.Block{
          number: sequence(""),
          hash: sequence("0x"),
          parent_hash: sequence("0x"),
          nonce: sequence(""),
          miner: sequence("0x"),
          difficulty: Enum.random(1..100_000),
          total_difficulty: Enum.random(1..100_000),
          size: Enum.random(1..100_000),
          gas_limit: Enum.random(1..100_000),
          gas_used: Enum.random(1..100_000),
          timestamp: DateTime.utc_now,
        }
      end
    end
  end
end
