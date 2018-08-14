defmodule EthereumJSONRPC.WebSocket do
  @moduledoc """
  JSONRPC over WebSocket.
  """

  alias EthereumJSONRPC.{Subscription, Transport}
  alias EthereumJSONRPC.WebSocket.Client

  @behaviour Transport

  @typedoc """
   * `pid` - a pre-existing `EthereumJSONRPC.WebSocket.Client` `t:pid/0`
  """
  @type options :: %{required(:pid) => pid}

  @impl Transport
  @spec json_rpc(Transport.request(), options) :: {:ok, Transport.result()} | {:error, reason :: term()}
  def json_rpc(request, %{pid: pid}) do
    Client.json_rpc(pid, request)
  end

  @impl Transport
  @spec subscribe(event :: Subscription.event(), params :: Subscription.params(), options) ::
          {:ok, Subscription.t()} | {:error, reason :: term()}
  def subscribe(event, params, %{pid: pid}) when is_binary(event) and is_list(params) do
    Client.subscribe(pid, event, params)
  end

  @impl Transport
  @spec unsubscribe(%Subscription{transport: __MODULE__, transport_options: %{pid: pid}}) :: :ok | :error
  def unsubscribe(%Subscription{transport: __MODULE__, transport_options: %{pid: pid}} = subscription) do
    Client.unsubscribe(pid, subscription)
  end
end
