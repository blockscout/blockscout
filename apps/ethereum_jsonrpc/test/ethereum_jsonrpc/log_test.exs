defmodule EthereumJSONRPC.LogTest do
  use ExUnit.Case, async: true

  doctest EthereumJSONRPC.Log

  alias EthereumJSONRPC.Log

  describe "to_elixir/1" do
    test "does not tries convert nils to integer" do
      input = %{
        "address" => "0xda8b3276cde6d768a44b9dac659faa339a41ac55",
        "blockHash" => nil,
        "blockNumber" => nil,
        "data" => "0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563",
        "logIndex" => "0x0",
        "removed" => false,
        "topics" => [
          "0xadc1e8a294f8415511303acc4a8c0c5906c7eb0bf2a71043d7f4b03b46a39130",
          "0x000000000000000000000000c15bf627accd3b054075c7880425f903106be72a",
          "0x000000000000000000000000a59eb37750f9c8f2e11aac6700e62ef89187e4ed"
        ],
        "transactionHash" => "0xf9b663b4e9b1fdc94eb27b5cfba04eb03d2f7b3fa0b24eb2e1af34f823f2b89e",
        "transactionIndex" => "0x0"
      }

      result = Log.to_elixir(input)

      assert result["blockNumber"] == nil
      assert result["blockHash"] == nil
    end
  end
end
