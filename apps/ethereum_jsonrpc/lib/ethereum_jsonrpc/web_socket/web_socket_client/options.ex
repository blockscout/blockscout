defmodule EthereumJSONRPC.WebSocket.WebSocketClient.Options do
  @moduledoc """
  `t:EthereumJSONRPC.WebSocket.options/0` for `EthereumJSONRPC.WebSocket.WebSocketClient` `t:EthereumJSONRPC.Subscription.t/0` `transport_options`.
  """

  alias EthereumJSONRPC.Subscription

  @enforce_keys ~w(web_socket)a
  defstruct ~w(web_socket event params)a

  @typedoc """
   * `web_socket` - the `t:pid/0` of the `EthereumJSONRPC.WebSocket.WebSocketClient`.
   * `event` - the event that should be resubscribed to after disconnect.
   * `params` - the parameters that should be used to customized `event` when resubscribing after disconnect.
  """
  @type t :: %__MODULE__{web_socket: pid(), event: Subscription.event(), params: Subscription.params()}
end
