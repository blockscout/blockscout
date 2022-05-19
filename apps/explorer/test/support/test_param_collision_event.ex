defmodule Explorer.Test.TestParamCollisionEvent do
  @moduledoc "An event with properties the same names as event struct properties "

  use Explorer.Celo.ContractEvents.Base,
    name: "TestName",
    topic: "0x08812eccd29961180ca7d99a726f3ec3d86acc2c0b7ad920180ca9d31f31c250"

  event_param(:name, :string, :unindexed)
  event_param(:topic, :string, :unindexed)
  event_param(:transaction_hash, :address, :indexed)
  event_param(:log_index, {:uint, 256}, :unindexed)
  event_param(:block_number, {:uint, 256}, :unindexed)

  def function_signature, do: "TestName(string,string,address,uint256,uint256)"
end
