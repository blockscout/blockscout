defmodule EthereumJSONRPC.ReceiptTest do
  use ExUnit.Case, async: true

  alias EthereumJSONRPC.Receipt

  doctest Receipt

  describe "to_elixir/1" do
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

    # Regression test for https://github.com/poanetwork/blockscout/issues/638
    test ~s|"status" => nil is treated the same as no status| do
      assert Receipt.to_elixir(%{"status" => nil, "transactionHash" => "0x0"}) == %{"transactionHash" => "0x0"}
    end
  end

  test "leaves nil if blockNumber is nil" do
    assert Receipt.to_elixir(%{"blockNumber" => nil, "transactionHash" => "0x0"}) == %{
             "transactionHash" => "0x0",
             "blockNumber" => nil
           }
  end
end
