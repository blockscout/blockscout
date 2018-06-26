defmodule EthereumJSONRPC.GethTest do
  use ExUnit.Case, async: false

  if EthereumJSONRPC.config(:variant) == EthereumJSONRPC.Geth do
    doctest EthereumJSONRPC.Geth
  end
end
