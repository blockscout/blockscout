defmodule Explorer.EthereumexExtensionsTest do
  use Explorer.DataCase
  alias Explorer.EthereumexExtensions

  describe "trace_transaction/1" do
    test "returns a transaction trace" do
      use_cassette "ethereumex_extensions_trace_transaction_1" do
        hash = "0x051e031f05b3b3a5ff73e1189c36e3e2a41fd1c2d9772b2c75349e22ed4d3f68"
        result = EthereumexExtensions.trace_transaction(hash)
        assert(is_list(result["trace"]))
      end
    end
  end
end
