defmodule EthereumJSONRPC.Case.Parity.Mox do
  @moduledoc """
  `EthereumJSONRPC.Case` for mocking connecting to Parity using `Mox`
  """

  def setup do
    %{
      block_interval: 500,
      json_rpc_named_arguments: [transport: EthereumJSONRPC.Mox, transport_options: [], variant: EthereumJSONRPC.Parity],
      subscribe_named_arguments: [transport: EthereumJSONRPC.Mox, transport_options: []]
    }
  end
end
