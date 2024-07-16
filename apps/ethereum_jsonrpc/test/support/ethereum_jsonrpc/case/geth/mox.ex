defmodule EthereumJSONRPC.Case.Geth.Mox do
  @moduledoc """
  `EthereumJSONRPC.Case` for mocking connecting to Geth using `Mox`
  """

  def setup do
    %{
      block_interval: 500,
      json_rpc_named_arguments: [
        transport: EthereumJSONRPC.Mox,
        transport_options: [http_options: [timeout: 60000, recv_timeout: 60000]],
        variant: EthereumJSONRPC.Geth
      ],
      subscribe_named_arguments: [transport: EthereumJSONRPC.Mox, transport_options: []]
    }
  end
end
