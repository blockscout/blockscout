defmodule EthereumJSONRPC.WebSocket.Registration do
  @moduledoc """
  When a caller registers for responses to asynchronous frame responses.
  """

  alias EthereumJSONRPC.Subscription

  @enforce_keys ~w(from type)a
  defstruct ~w(from type subscription_id)a

  @typedoc """
  What kind of request will be issued by the caller

    * `:json_rpc` - a generic JSONRPC request that just needs to be returned to the caller based on `id` matching.
    * `:subscribe` - an `eth_subscribe` request will be issued by the caller.  Its response need to be returned to
      caller **AND** the client needs to `EthereumsJSONRPC.Subscription.publish/2` any `eth_subscription` messages to
      the caller until the `EthereumJSONRPC.WebSocket.Client.unsubscribe/1` is called.
    * `:unsubscribe` - an `eth_unsubscribe` request will be issued by the caller.  Its response needs to be returned to
      caller **AND** the client needs to stop tracking the subscription.
  """
  @type type :: :json_rpc | :subscribe | :unsubscribe

  @type t :: %__MODULE__{from: GenServer.from(), type: type, subscription_id: Subscription.id()}
end
