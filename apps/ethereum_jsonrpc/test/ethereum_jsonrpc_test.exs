defmodule EthereumJsonrpcTest do
  use ExUnit.Case
  doctest EthereumJsonrpc

  test "greets the world" do
    assert EthereumJsonrpc.hello() == :world
  end
end
