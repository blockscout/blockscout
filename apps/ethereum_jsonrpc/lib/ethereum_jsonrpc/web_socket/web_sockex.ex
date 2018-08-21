defmodule EthereumJSONRPC.WebSocket.WebSockex do
  @moduledoc """
  Implements `EthereumJSONRPC.WebSocket` using `WebSockex`.
  """

  use WebSockex

  require Logger

  import EthereumJSONRPC, only: [request: 1]

  alias EthereumJSONRPC.{Subscription, Transport, WebSocket}
  alias EthereumJSONRPC.WebSocket.Registration

  @behaviour WebSocket

  @enforce_keys ~w(url)a
  defstruct request_id_to_registration: %{},
            subscription_id_to_subscription: %{},
            url: nil

  @type t :: %__MODULE__{
          request_id_to_registration: %{non_neg_integer() => Registration.t()},
          subscription_id_to_subscription: %{String.t() => Subscription.t()},
          url: String.t()
        }

  # Supervisor interface

  @impl WebSocket
  # only allow secure WSS
  def start_link(["wss://" <> _ = url, gen_server_options]) when is_list(gen_server_options) do
    WebSockex.start_link(url, __MODULE__, %__MODULE__{url: url}, [
      {:cacerts, :certifi.cacerts()},
      {:insecure, false} | gen_server_options
    ])
  end

  # Client interface

  @impl WebSocket
  @spec json_rpc(WebSocket.web_socket(), Transport.request()) :: {:ok, Transport.result()} | {:error, reason :: term()}
  def json_rpc(client, request) do
    unique_id = EthereumJSONRPC.unique_request_id()
    unique_request = Map.put(request, :id, unique_id)

    {:ok, reference} = GenServer.call(client, {:register, %{id: unique_id, type: :json_rpc}})
    WebSockex.send_frame(client, {:text, Jason.encode!(unique_request)})

    receive do
      {^reference, reply} -> reply
    after
      5000 ->
        exit(:timeout)
    end
  end

  @impl WebSocket
  @spec subscribe(WebSocket.web_socket(), Subscription.event(), Subscription.params()) ::
          {:ok, Subscription.t()} | {:error, reason :: term()}
  def subscribe(client, event, params) when is_binary(event) and is_list(params) do
    unique_id = EthereumJSONRPC.unique_request_id()

    unique_request =
      %{id: unique_id, method: "eth_subscribe", params: [event | params]}
      |> request()

    {:ok, reference} = GenServer.call(client, {:register, %{id: unique_id, type: :subscribe}})
    WebSockex.send_frame(client, {:text, Jason.encode!(unique_request)})

    receive do
      {^reference, reply} -> reply
    after
      5000 ->
        exit(:timeout)
    end
  end

  @impl WebSocket
  @spec unsubscribe(WebSocket.web_socket(), Subscription.t()) :: :ok | {:error, :not_found}
  def unsubscribe(client, %Subscription{id: subscription_id}) do
    unique_id = EthereumJSONRPC.unique_request_id()

    unique_request =
      %{id: unique_id, method: "eth_unsubscribe", params: [subscription_id]}
      |> request()

    with {:ok, reference} <-
           GenServer.call(client, {:register, %{id: unique_id, type: :unsubscribe, subscription_id: subscription_id}}) do
      WebSockex.send_frame(client, {:text, Jason.encode!(unique_request)})

      receive do
        {^reference, reply} -> reply
      after
        5000 ->
          exit(:timeout)
      end
    end
  end

  # WebSockex functions

  @impl WebSockex
  def handle_frame({:text, message}, %__MODULE__{} = state) do
    case Jason.decode(message) do
      {:ok, json} ->
        handle_response(json, state)

      {:error, _} = error ->
        broadcast(error, state)
        {:ok, state}
    end
  end

  @impl WebSockex
  def handle_info({:"$gen_call", from, request}, %__MODULE__{} = state) do
    handle_call(request, from, state)
  end

  defp handle_call(
         {:register, %{id: id} = options},
         from,
         %__MODULE__{request_id_to_registration: request_id_to_registration} = state
       )
       when is_integer(id) do
    case request_id_to_registration do
      %{^id => _} ->
        GenServer.reply(from, {:error, :already_registered})
        {:ok, state}

      _ ->
        register(options, from, state)
    end
  end

  defp register(%{id: id, type: type}, {_, reference} = from, state)
       when type in ~w(json_rpc subscribe)a and is_reference(reference) do
    GenServer.reply(from, {:ok, reference})

    {:ok, put_in(state.request_id_to_registration[id], %Registration{from: from, type: type})}
  end

  defp register(
         %{id: id, type: :unsubscribe = type, subscription_id: subscription_id},
         {_, reference} = from,
         %__MODULE__{subscription_id_to_subscription: subscription_id_to_subscription} = state
       )
       when is_reference(reference) do
    case subscription_id_to_subscription do
      %{^subscription_id => _} ->
        GenServer.reply(from, {:ok, reference})

        {:ok,
         put_in(state.request_id_to_registration[id], %Registration{
           from: from,
           type: type,
           subscription_id: subscription_id
         })}

      _ ->
        GenServer.reply(from, {:error, :not_found})
        {:ok, state}
    end
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
            "Unexpected `eth_subscription` subscripton ID (",
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

  defp broadcast(message, %__MODULE__{subscription_id_to_subscription: id_to_subscription}) do
    id_to_subscription
    |> Map.values()
    |> Subscription.broadcast(message)
  end
end
