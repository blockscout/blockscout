defmodule EthereumJSONRPC.TransactionTest do
  use ExUnit.Case, async: true

  doctest EthereumJSONRPC.Transaction

  alias EthereumJSONRPC.Transaction

  describe "to_elixir/1" do
    test "skips unsupported keys" do
      map = %{"key" => "value", "key1" => "value1"}

      assert %{nil: nil} = Transaction.to_elixir(map)
    end
  end
end
