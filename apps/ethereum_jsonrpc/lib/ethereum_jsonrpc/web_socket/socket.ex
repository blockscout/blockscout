defmodule EthereumJSONRPC.WebSocket.Socket do
  @moduledoc """
  Implements `EthereumJSONRPC.WebSocket` using `Socket.Web`.
  """

  use GenServer

  require Logger

  import EthereumJSONRPC, only: [request: 1]

  alias EthereumJSONRPC.{Subscription, Transport, WebSocket}
  alias EthereumJSONRPC.WebSocket.Registration
  alias EthereumJSONRPC.WebSocket.Socket.Receiver

  @behaviour WebSocket

  @enforce_keys ~w(receiver socket_web url)a
  defstruct receiver: nil,
            request_id_to_registration: %{},
            socket_web: nil,
            subscription_id_to_subscription: %{},
            url: nil

  @type t :: %__MODULE__{
          receiver: pid(),
          request_id_to_registration: %{non_neg_integer() => Registration.t()},
          socket_web: Socket.Web.t(),
          subscription_id_to_subscription: %{Subscription.id() => Subscription.t()},
          url: String.t()
        }

  # Supervisor interface

  @impl WebSocket
  # only allow secure WSS
  def start_link(["wss://" <> _ = url, gen_server_options]) when is_list(gen_server_options) do
    GenServer.start_link(__MODULE__, url, gen_server_options)
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

  @impl GenServer
  def init("wss://" <> _ = url) do
    uri = URI.parse(url)
    address = uri_to_address(uri)

    options =
      options_put_uri(
        [
          authorities: [path: :certifi.cacertfile()],
          partial_chain: &partial_chain/1,
          secure: true,
          server_name: uri.host,
          verify: [function: &:ssl_verify_hostname.verify_fun/3, data: [check_hostname: String.to_charlist(uri.host)]]
        ],
        uri
      )

    case Socket.Web.connect(address, options) do
      {:ok, socket_web} ->
        receiver = Receiver.spawn_link(%{parent: self(), socket_web: socket_web})
        {:ok, %__MODULE__{receiver: receiver, socket_web: socket_web, url: url}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call(message, from, %__MODULE__{socket_web: socket_web} = state) do
    {updated_state, unique_request} = register(message, from, state)

    Socket.Web.send(socket_web, {:text, Jason.encode!(unique_request)})

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast({:text, text}, %__MODULE__{} = state) do
    case Jason.decode(text) do
      {:ok, json} ->
        handle_response(json, state)

      {:error, _} = error ->
        broadcast(error, state)
        {:noreply, state}
    end
  end

  def handle_cast(:close = close, %__MODULE__{} = state) do
    broadcast({:error, close}, state)
  end

  def handle_cast({:close, _code, _data} = close, %__MODULE__{} = state) do
    broadcast({:error, close}, state)
  end

  def handle_cast({:error, _reason} = error, %__MODULE__{} = state) do
    broadcast(error, state)
  end

  defp broadcast(message, %__MODULE__{subscription_id_to_subscription: id_to_subscription}) do
    id_to_subscription
    |> Map.values()
    |> Subscription.broadcast(message)
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

    {:noreply, state}
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

    {:noreply, state}
  end

  defp options_put_uri(options, %URI{path: nil}), do: options

  defp options_put_uri(options, %URI{path: path}) when is_binary(path) do
    Keyword.put(options, :path, path)
  end

  defp partial_chain(certs) do
    raise "BBOOM: #{inspect certs}"
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

    {:noreply, %__MODULE__{state | request_id_to_registration: new_request_id_to_registration}}
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

    {:noreply, new_state}
  end

  defp respond_to_registration(
         %Registration{type: :subscribe, from: from},
         new_request_id_to_registration,
         %{"error" => error},
         %__MODULE__{} = state
       ) do
    GenServer.reply(from, {:error, error})

    {:noreply, %__MODULE__{state | request_id_to_registration: new_request_id_to_registration}}
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
        %{"error" => error} -> {:error, error}
      end

    GenServer.reply(from, reply)

    new_state =
      state
      |> put_in([Access.key!(:request_id_to_registration)], new_request_id_to_registration)
      |> update_in([Access.key!(:subscription_id_to_subscription)], &Map.delete(&1, subscription_id))

    {:noreply, new_state}
  end

  defp respond_to_registration(nil, _, response, %__MODULE__{} = state) do
    Logger.error(fn -> ["Got response for unregistered request ID: ", inspect(response)] end)

    {:noreply, state}
  end

  defp uri_to_address(%URI{host: host, port: nil}), do: host
  defp uri_to_address(%URI{host: host, port: port}) when is_integer(port), do: {host, port}
end
