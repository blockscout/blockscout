defmodule EthereumJSONRPC.WebSocket.WebSocketClient do
  @moduledoc """
  `EthereumJSONRPC.WebSocket` that uses `websocket_client`
  """

  require Logger

  import EthereumJSONRPC, only: [request: 1]

  alias EthereumJSONRPC.{Subscription, Transport, WebSocket}
  alias EthereumJSONRPC.WebSocket.Registration

  @behaviour :websocket_client
  @behaviour WebSocket

  @enforce_keys ~w(url)a
  defstruct request_id_to_registration: %{},
            subscription_id_to_subscription: %{},
            url: nil

  # Supervisor interface

  @impl WebSocket
  def child_spec(arg) do
    Supervisor.child_spec(%{id: __MODULE__, start: {__MODULE__, :start_link, [arg]}}, [])
  end

  @impl WebSocket
  # only allow secure WSS
  def start_link(["wss://" <> _ = url, gen_fsm_options]) when is_list(gen_fsm_options) do
    fsm_name =
      case Keyword.fetch(gen_fsm_options, :name) do
        {:ok, name} when is_atom(name) -> {:local, name}
        :error -> :undefined
      end

    %URI{host: host} = URI.parse(url)
    host_charlist = String.to_charlist(host)

    # `:depth`, `:verify`, and `:verify_fun`, are based on `:hackney_connect.ssl_opts_1/2` as we use `:hackney` through
    # `:httpoison` and this keeps the SSL rules consistent between HTTP and WebSocket
    :websocket_client.start_link(
      fsm_name,
      url,
      __MODULE__,
      url,
      ssl_verify: :verify_peer,
      socket_opts: [
        cacerts: :certifi.cacerts(),
        depth: 99,
        # SNI extension discloses host name in the clear, but allows for compatibility with Virtual Hosting for TLS
        server_name_indication: host_charlist,
        verify_fun: {&:ssl_verify_hostname.verify_fun/3, [check_hostname: host_charlist]}
      ]
    )
  end

  # Client interface

  @impl WebSocket
  @spec json_rpc(WebSocket.web_socket(), Transport.request()) :: {:ok, Transport.result()} | {:error, reason :: term()}
  def json_rpc(web_socket, request) do
    GenServer.call(web_socket, {:json_rpc, request})
  end

  @impl WebSocket
  @spec subscribe(WebSocket.web_socket(), Subscription.event(), Subscription.params()) ::
          {:ok, Subscription.t()} | {:error, reason :: term()}
  def subscribe(web_socket, event, params) when is_binary(event) and is_list(params) do
    GenServer.call(web_socket, {:subscribe, event, params})
  end

  @impl WebSocket
  @spec unsubscribe(WebSocket.web_socket(), Subscription.t()) :: :ok | {:error, :not_found}
  def unsubscribe(web_socket, %Subscription{} = subscription) do
    GenServer.call(web_socket, {:unsubscribe, subscription})
  end

  @impl :websocket_client
  def init(url) do
    {:reconnect, %__MODULE__{url: url}}
  end

  @impl :websocket_client
  def onconnect(_, %__MODULE__{} = state) do
    {:ok, state}
  end

  @impl :websocket_client
  def ondisconnect(reason, %__MODULE__{} = state) do
    {:close, reason, state}
  end

  @impl :websocket_client
  def websocket_handle({:text, text}, _request, %__MODULE__{} = state) do
    case Jason.decode(text) do
      {:ok, json} ->
        handle_response(json, state)

      {:error, _} = error ->
        broadcast(error, state)
        {:ok, state}
    end
  end

  @impl :websocket_client
  def websocket_info({:"$gen_call", from, request}, _, %__MODULE__{} = state) do
    handle_call(request, from, state)
  end

  @impl :websocket_client
  def websocket_terminate(close, _request, %__MODULE__{} = state) do
    broadcast(close, state)
  end

  defp broadcast(message, %__MODULE__{subscription_id_to_subscription: id_to_subscription}) do
    id_to_subscription
    |> Map.values()
    |> Subscription.broadcast(message)
  end

  defp handle_call(message, from, %__MODULE__{} = state) do
    {updated_state, unique_request} = register(message, from, state)

    {:reply, {:text, Jason.encode!(unique_request)}, updated_state}
  end

  defp handle_response(
         %{"method" => "eth_subscription", "params" => %{"result" => result, "subscription" => subscription_id}},
         %__MODULE__{subscription_id_to_subscription: subscription_id_to_subscription} = state
       ) do
    case subscription_id_to_subscription do
      %{^subscription_id => subscription} ->
        Subscription.publish(subscription, {:ok, result})

      _ ->
        Logger.error(fn ->
          [
            "Unexpected `eth_subscription` subscription ID (",
            inspect(subscription_id),
            ") result (",
            inspect(result),
            ").  Subscription ID not in known subscription IDs (",
            subscription_id_to_subscription
            |> Map.values()
            |> Enum.map(&inspect/1),
            ")."
          ]
        end)
    end

    {:ok, state}
  end

  defp handle_response(
         %{"id" => id} = response,
         %__MODULE__{request_id_to_registration: request_id_to_registration} = state
       ) do
    {registration, new_request_id_to_registration} = Map.pop(request_id_to_registration, id)
    respond_to_registration(registration, new_request_id_to_registration, response, state)
  end

  defp handle_response(response, %__MODULE__{} = state) do
    Logger.error(fn ->
      [
        "Unexpected JSON response from web socket\n",
        "\n",
        "  Response:\n",
        "    ",
        inspect(response)
      ]
    end)

    {:ok, state}
  end

  defp register(
         {:json_rpc, original_request},
         from,
         %__MODULE__{request_id_to_registration: request_id_to_registration} = state
       ) do
    unique_id = unique_request_id(state)

    {%__MODULE__{
       state
       | request_id_to_registration:
           Map.put(request_id_to_registration, unique_id, %Registration{
             from: from,
             type: :json_rpc
           })
     }, %{original_request | id: unique_id}}
  end

  defp register(
         {:subscribe, event, params},
         from,
         %__MODULE__{request_id_to_registration: request_id_to_registration} = state
       )
       when is_binary(event) and is_list(params) do
    unique_id = unique_request_id(state)

    {
      %__MODULE__{
        state
        | request_id_to_registration:
            Map.put(request_id_to_registration, unique_id, %Registration{from: from, type: :subscribe})
      },
      request(%{id: unique_id, method: "eth_subscribe", params: [event | params]})
    }
  end

  defp register(
         {:unsubscribe, %Subscription{id: subscription_id}},
         from,
         %__MODULE__{request_id_to_registration: request_id_to_registration} = state
       ) do
    unique_id = unique_request_id(state)

    {
      %__MODULE__{
        state
        | request_id_to_registration:
            Map.put(request_id_to_registration, unique_id, %Registration{
              from: from,
              type: :unsubscribe,
              subscription_id: subscription_id
            })
      },
      request(%{id: unique_id, method: "eth_unsubscribe", params: [subscription_id]})
    }
  end

  defp respond_to_registration(
         %Registration{type: :json_rpc, from: from},
         new_request_id_to_registration,
         response,
         %__MODULE__{} = state
       ) do
    reply =
      case response do
        %{"result" => result} -> {:ok, result}
        %{"error" => error} -> {:error, error}
      end

    GenServer.reply(from, reply)

    {:ok, %__MODULE__{state | request_id_to_registration: new_request_id_to_registration}}
  end

  defp respond_to_registration(
         %Registration{type: :subscribe, from: {subscriber_pid, _} = from},
         new_request_id_to_registration,
         %{"result" => subscription_id},
         %__MODULE__{url: url} = state
       ) do
    subscription = %Subscription{
      id: subscription_id,
      subscriber_pid: subscriber_pid,
      transport: EthereumJSONRPC.WebSocket,
      transport_options: [web_socket: __MODULE__, web_socket_options: %{web_socket: self()}, url: url]
    }

    GenServer.reply(from, {:ok, subscription})

    new_state =
      state
      |> put_in([Access.key!(:request_id_to_registration)], new_request_id_to_registration)
      |> put_in([Access.key!(:subscription_id_to_subscription), subscription_id], subscription)

    {:ok, new_state}
  end

  defp respond_to_registration(
         %Registration{type: :subscribe, from: from},
         new_request_id_to_registration,
         %{"error" => error},
         %__MODULE__{} = state
       ) do
    GenServer.reply(from, {:error, error})

    {:ok, %__MODULE__{state | request_id_to_registration: new_request_id_to_registration}}
  end

  defp respond_to_registration(
         %Registration{type: :unsubscribe, from: from, subscription_id: subscription_id},
         new_request_id_to_registration,
         response,
         %__MODULE__{} = state
       ) do
    reply =
      case response do
        %{"result" => true} -> :ok
        %{"result" => false} -> {:error, :not_found}
        %{"error" => %{"message" => "subscription not found"}} -> {:error, :not_found}
        %{"error" => error} -> {:error, error}
      end

    GenServer.reply(from, reply)

    new_state =
      state
      |> put_in([Access.key!(:request_id_to_registration)], new_request_id_to_registration)
      |> update_in([Access.key!(:subscription_id_to_subscription)], &Map.delete(&1, subscription_id))

    {:ok, new_state}
  end

  defp respond_to_registration(nil, _, response, %__MODULE__{} = state) do
    Logger.error(fn -> ["Got response for unregistered request ID: ", inspect(response)] end)

    {:ok, state}
  end

  defp unique_request_id(%__MODULE__{request_id_to_registration: request_id_to_registration} = state) do
    unique_request_id = EthereumJSONRPC.unique_request_id()

    case request_id_to_registration do
      # collision
      %{^unique_request_id => _} ->
        unique_request_id(state)

      _ ->
        unique_request_id
    end
  end
end
