defmodule EthereumJSONRPC.ZilliqaTest do
  use ExUnit.Case, async: true

  doctest EthereumJSONRPC.Zilliqa.Helper
  doctest EthereumJSONRPC.Zilliqa.AggregateQuorumCertificate
  doctest EthereumJSONRPC.Zilliqa.NestedQuorumCertificates
  doctest EthereumJSONRPC.Zilliqa.QuorumCertificate
end
