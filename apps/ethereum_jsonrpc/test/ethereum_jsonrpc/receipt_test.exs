defmodule EthereumJSONRPC.ReceiptTest do
  use ExUnit.Case, async: true

  alias EthereumJSONRPC.Receipt

  doctest Receipt

  describe "to_elixir/1" do
    test "with status with nil raises ArgumentError with full receipt" do
      assert_raise ArgumentError,
                   """
                   Could not convert receipt to elixir

                   Receipt:
                     %{"status" => nil, "transactionHash" => "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060"}

                   Errors:
                     {:unknown_value, %{key: "status", value: nil}}
                   """,
                   fn ->
                     Receipt.to_elixir(%{
                       "status" => nil,
                       "transactionHash" => "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060"
                     })
                   end
    end

    test "with new key raise ArgumentError with full receipt" do
      assert_raise ArgumentError,
                   """
                   Could not convert receipt to elixir

                   Receipt:
                     %{"new_key" => "new_value", "transactionHash" => "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060"}

                   Errors:
                     {:unknown_key, %{key: "new_key", value: "new_value"}}
                   """,
                   fn ->
                     Receipt.to_elixir(%{
                       "new_key" => "new_value",
                       "transactionHash" => "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060"
                     })
                   end
    end
  end
end
