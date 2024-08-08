defmodule EthereumJSONRPC.WebSocket do
  @moduledoc """
  JSONRPC over WebSocket.
  """

  alias EthereumJSONRPC.{Subscription, Transport}

  @behaviour Transport

  @enforce_keys ~w(url web_socket)a
  defstruct ~w(url fallback_url web_socket web_socket_options)a

  @typedoc """
  WebSocket name
  """
  # same as `t:GenServer.name/0`
  @type name :: atom() | {:global, term()} | {:via, module(), term()}

  @typedoc """
  WebSocket reference
  """
  # same as `t:GenServer.server/0`
  @type web_socket :: pid() | name() | {atom(), node()}

  @typedoc """
  Options for `web_socket` `t:module/0` in `t:t/0`.
  """
  @type web_socket_options :: %{required(:web_socket) => web_socket(), optional(atom()) => term()}

  @typedoc """
  Options passed to `EthereumJSONRPC.Transport` callbacks.

  **MUST** contain `t:web_socket/0` referring to `t:pid/0` returned by `c:start_link/2`.
  """
  @type t :: %__MODULE__{web_socket: module(), web_socket_options: web_socket_options}

  @doc """
  Allow `c:start_link/1` to be called as part of a supervision tree.
  """
  @callback child_spec([(url :: String.t()) | (options :: term())]) :: Supervisor.child_spec()

  @doc """
  Starts web socket attached to `url` with `options`.
  """
  # Return is same as `t:GenServer.on_start/0`
  @callback start_link(url :: String.t(), options :: term()) ::
              {:ok, pid()} | :ignore | {:error, {:already_started, pid()} | (reason :: term())}

  @doc """
  Run a single Remote Procedure Call (RPC) `t:EthereumJSONRPC.Transport.request/0` through `t:web_socket/0`.

  ## Returns

   * `{:ok, result}` - `result` is the `/result` from JSONRPC response object of format
     `%{"id" => ..., "result" => result}`.
   * `{:error, reason}` - `reason` is the `/error` from JSONRPC response object of format
     `%{"id" => ..., "error" => reason}`.  The transport can also give any `term()` for `reason` if a more specific
     reason is possible.

  """
  @callback json_rpc(web_socket(), Transport.request()) :: {:ok, Transport.result()} | {:error, reason :: term()}

  @doc """
  Subscribes to `t:EthereumJSONRPC.Subscription.event/0` with `t:EthereumJSONRPC.Subscription.params/0` through
  `t:web_socket/0`.

  Events are delivered in a tuple tagged with the `t:EthereumJSONRPC.Subscription.t/0` and containing the same output
  as `json_rpc/2`.

  | Message                                                                           | Description                            |
  |-----------------------------------------------------------------------------------|----------------------------------------|
  | `{EthereumJSONRPC.Subscription.t(), {:ok, EthereumJSONRPC.Transport.result.t()}}` | New result in subscription             |
  | `{EthereumJSONRPC.Subscription.t(), {:error, reason :: term()}}`                  | There was an error in the subscription |

  Subscription can be canceled by calling `unsubscribe/1` with the returned `t:EthereumJSONRPC.Subscription.t/0`.
  """
  @callback subscribe(web_socket(), event :: Subscription.event(), params :: Subscription.params()) ::
              {:ok, Subscription.t()} | {:error, reason :: term()}

  @doc """
  Unsubscribes to `t:EthereumJSONRPC.Subscription.t/0` created with `subscribe/2`.

  ## Returns

   * `:ok` - subscription was canceled
   * `{:error, reason}` - subscription could not be canceled.

  """
  @callback unsubscribe(web_socket(), Subscription.t()) :: :ok | {:error, reason :: term()}

  @impl Transport
  @spec json_rpc(Transport.request(), t()) :: {:ok, Transport.result()} | {:error, reason :: term()}
  def json_rpc(request, %__MODULE__{web_socket: web_socket_module, web_socket_options: %{web_socket: web_socket}}) do
    web_socket_module.json_rpc(web_socket, request)
  end

  @impl Transport
  @spec subscribe(event :: Subscription.event(), params :: Subscription.params(), t()) ::
          {:ok, Subscription.t()} | {:error, reason :: term()}
  def subscribe(event, params, %__MODULE__{web_socket: web_socket_module, web_socket_options: %{web_socket: web_socket}})
      when is_binary(event) and is_list(params) do
    web_socket_module.subscribe(web_socket, event, params)
  end

  @impl Transport
  @spec unsubscribe(Subscription.t()) :: :ok | {:error, reason :: term()}
  def unsubscribe(
        %Subscription{
          transport: __MODULE__,
          transport_options: %__MODULE__{web_socket: web_socket_module, web_socket_options: %{web_socket: web_socket}}
        } = subscription
      ) do
    web_socket_module.unsubscribe(web_socket, subscription)
  end
end
