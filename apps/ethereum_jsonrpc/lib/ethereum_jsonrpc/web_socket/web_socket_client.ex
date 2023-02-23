defmodule EthereumJSONRPC.WebSocket.WebSocketClient do
  @moduledoc """
  `EthereumJSONRPC.WebSocket` that uses `websocket_client`
  """

  require Logger

  import EthereumJSONRPC, only: [request: 1]

  alias EthereumJSONRPC.{Subscription, Transport, WebSocket}
  alias EthereumJSONRPC.WebSocket.Registration
  alias EthereumJSONRPC.WebSocket.WebSocketClient.Options

  @behaviour :websocket_client
  @behaviour WebSocket

  @enforce_keys ~w(url)a
  defstruct connected: false,
            request_id_to_registration: %{},
            subscription_id_to_subscription_reference: %{},
            subscription_reference_to_subscription_id: %{},
            subscription_reference_to_subscription: %{},
            url: nil

  @typedoc """
   * `request_id_to_registration` - maps id of requests in flight to their
     `t:EthereumSJONRPC.WebSocket.Registration.t/0`, so that when the response is received from the server, the caller
     in `from` of the registration can be `GenServer.reply/2`ed to.
   * `subscription_id_to_subscription_reference` - maps id of subscription on the server to the `t:reference/0` used in
     the `t:EthereumJSONRPC.Subscription.t/0`.  Subscriptions use a `t:reference/0` instead of the server-side id, so
     that on reconnect, the id can change, but the subscribe does not need to be notified.
   * `subscription_reference_to_subscription` - maps `t:reference/0` in `t:EthereumJSONRPC.Subscription.t/0` to that
     `t:EthereumJSONRPC.Subscription.t/0`, so that the `subscriber_pid` can be notified of subscription messages.
   * `subscription_reference_to_subscription_id` - maps `t:reference/0` in `t:EthereumJSONRPC.Subscription.t/0  to id of
     the subscription on the server, so that the subscriber can unsubscribe with the `t:reference/0`.
  """
  @type t :: %__MODULE__{
          request_id_to_registration: %{EthereumJSONRPC.request_id() => Registration.t()},
          subscription_id_to_subscription_reference: %{Subscription.id() => reference()},
          subscription_reference_to_subscription: %{reference() => Subscription.t()},
          subscription_reference_to_subscription_id: %{reference() => Subscription.id()}
        }

  # Supervisor interface

  @impl WebSocket
  def child_spec(arg) do
    Supervisor.child_spec(%{id: __MODULE__, start: {__MODULE__, :start_link, [arg]}}, [])
  end

  @impl WebSocket
  # only allow secure WSS
  def start_link(["wss://" <> _ = url, websocket_opts, gen_fsm_options]) when is_list(gen_fsm_options) do
    keepalive = websocket_opts[:keepalive]

    fsm_name =
      case Keyword.fetch(gen_fsm_options, :name) do
        {:ok, name} when is_atom(name) -> {:local, name}
        :error -> :undefined
      end

    %URI{host: host} = URI.parse(url)
    host_charlist = String.to_charlist(host)

    :ssl.start()

    # `:depth`, `:verify`, and `:verify_fun`, are based on `:hackney_connect.ssl_opts_1/2` as we use `:hackney` through
    # `:httpoison` and this keeps the SSL rules consistent between HTTP and WebSocket
    :websocket_client.start_link(
      fsm_name,
      url,
      __MODULE__,
      url,
      ssl_verify: :verify_peer,
      keepalive: keepalive,
      socket_opts: [
        cacerts: :certifi.cacerts(),
        depth: 99,
        # SNI extension discloses host name in the clear, but allows for compatibility with Virtual Hosting for TLS
        server_name_indication: host_charlist,
        verify_fun: {&:ssl_verify_hostname.verify_fun/3, [check_hostname: host_charlist]},
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    )
  end

  def start_link(["ws://" <> _ = url, websocket_opts, gen_fsm_options]) when is_list(gen_fsm_options) do
    keepalive = websocket_opts[:keepalive]

    fsm_name =
      case Keyword.fetch(gen_fsm_options, :name) do
        {:ok, name} when is_atom(name) -> {:local, name}
        :error -> :undefined
      end

    :websocket_client.start_link(
      fsm_name,
      url,
      __MODULE__,
      url,
      keepalive: keepalive
    )
  end

  # Client interface

  @impl WebSocket
  @spec json_rpc(WebSocket.web_socket(), Transport.request()) :: {:ok, Transport.result()} | {:error, reason :: term()}
  def json_rpc(web_socket, request) do
    GenServer.call(web_socket, {:gen_call, {:json_rpc, request}})
  end

  @impl WebSocket
  @spec subscribe(WebSocket.web_socket(), Subscription.event(), Subscription.params()) ::
          {:ok, Subscription.t()} | {:error, reason :: term()}
  def subscribe(web_socket, event, params) when is_binary(event) and is_list(params) do
    GenServer.call(web_socket, {:gen_call, {:subscribe, event, params}})
  end

  @impl WebSocket
  @spec unsubscribe(WebSocket.web_socket(), Subscription.t()) :: :ok | {:error, :not_found}
  def unsubscribe(web_socket, %Subscription{} = subscription) do
    GenServer.call(web_socket, {:gen_call, {:unsubscribe, subscription}})
  end

  @impl :websocket_client
  def init(url) do
    {:reconnect, %__MODULE__{url: url}}
  end

  @impl :websocket_client
  def onconnect(_, %__MODULE__{connected: false} = state) do
    {:ok, reconnect(%__MODULE__{state | connected: true})}
  end

  @impl :websocket_client
  def ondisconnect(_reason, %__MODULE__{request_id_to_registration: request_id_to_registration} = state) do
    final_state = Enum.reduce(request_id_to_registration, state, &disconnect_request_id_registration/2)

    {:reconnect, %__MODULE__{final_state | connected: false}}
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
  def websocket_handle({:ping, ""}, _request, %__MODULE__{} = state), do: {:reply, {:pong, ""}, state}

  @impl :websocket_client
  def websocket_handle({:pong, _}, _request, state) do
    {:ok, state}
  end

  @impl :websocket_client
  def websocket_info({{:gen_call, request}, from}, _, %__MODULE__{} = state) do
    case handle_call(request, from, state) do
      {:reply, _, %__MODULE__{}} = reply -> reply
      {:noreply, %__MODULE__{} = new_state} -> {:ok, new_state}
    end
  end

  @impl :websocket_client
  def websocket_terminate(close, _request, %__MODULE__{} = state) do
    broadcast(close, state)
  end

  defp broadcast(message, %__MODULE__{subscription_reference_to_subscription: subscription_reference_to_subscription}) do
    subscription_reference_to_subscription
    |> Map.values()
    |> Subscription.broadcast(message)
  end

  # Not re-subscribing after disconnect is the same as a successful unsubscribe
  defp disconnect_request_id_registration(
         {request_id,
          %Registration{
            type: :unsubscribe,
            from: from,
            request: %{method: "eth_unsubscribe", params: [subscription_id]}
          }},
         %__MODULE__{
           request_id_to_registration: request_id_to_registration,
           subscription_id_to_subscription_reference: subscription_id_to_subscription_reference,
           subscription_reference_to_subscription: subscription_reference_to_subscription,
           subscription_reference_to_subscription_id: subscription_reference_to_subscription_id
         } = acc_state
       ) do
    GenServer.reply(from, :ok)

    %{^subscription_id => subscription_reference} = subscription_id_to_subscription_reference

    %__MODULE__{
      acc_state
      | request_id_to_registration: Map.delete(request_id_to_registration, request_id),
        subscription_id_to_subscription_reference:
          Map.delete(subscription_id_to_subscription_reference, subscription_id),
        subscription_reference_to_subscription:
          Map.delete(subscription_reference_to_subscription, subscription_reference),
        subscription_reference_to_subscription_id:
          Map.delete(subscription_reference_to_subscription_id, subscription_reference)
    }
  end

  # Re-run in `onconnect\2`
  defp disconnect_request_id_registration({_request_id, %Registration{type: type}}, state)
       when type in ~w(json_rpc subscribe)a do
    state
  end

  defp frame(request) do
    {:text, Jason.encode!(request)}
  end

  defp handle_call(message, from, %__MODULE__{connected: connected} = state) do
    case register(message, from, state) do
      {:ok, unique_request, updated_state} ->
        case connected do
          true ->
            {:reply, frame(unique_request), updated_state}

          false ->
            {:noreply, updated_state}
        end

      {:error, _reason} = error ->
        GenServer.reply(from, error)
        {:noreply, state}
    end
  end

  defp handle_response(
         %{"method" => "eth_subscription", "params" => %{"result" => result, "subscription" => subscription_id}},
         %__MODULE__{
           subscription_id_to_subscription_reference: subscription_id_to_subscription_reference,
           subscription_reference_to_subscription: subscription_reference_to_subscription
         } = state
       ) do
    case subscription_id_to_subscription_reference do
      %{^subscription_id => subscription_reference} ->
        %{^subscription_reference => subscription} = subscription_reference_to_subscription
        Subscription.publish(subscription, {:ok, result})

      _ ->
        Logger.error(fn ->
          [
            "Unexpected `eth_subscription` subscription ID (",
            inspect(subscription_id),
            ") result (",
            inspect(result),
            ").  Subscription ID not in known subscription IDs (",
            subscription_id_to_subscription_reference
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
    new_state = %__MODULE__{state | request_id_to_registration: new_request_id_to_registration}

    respond_to_registration(registration, response, new_state)
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

  defp reconnect(%__MODULE__{} = state) do
    state
    |> rerequest()
    |> resubscribe()
  end

  defp register(
         {:json_rpc, original_request},
         from,
         %__MODULE__{request_id_to_registration: request_id_to_registration} = state
       ) do
    unique_id = unique_request_id(state)
    request = %{original_request | id: unique_id}

    {:ok, request,
     %__MODULE__{
       state
       | request_id_to_registration:
           Map.put(request_id_to_registration, unique_id, %Registration{
             from: from,
             type: :json_rpc,
             request: request
           })
     }}
  end

  defp register(
         {:subscribe, event, params},
         from,
         %__MODULE__{request_id_to_registration: request_id_to_registration} = state
       )
       when is_binary(event) and is_list(params) do
    unique_id = unique_request_id(state)
    request = request(%{id: unique_id, method: "eth_subscribe", params: [event | params]})

    {:ok, request,
     %__MODULE__{
       state
       | request_id_to_registration:
           Map.put(request_id_to_registration, unique_id, %Registration{from: from, type: :subscribe, request: request})
     }}
  end

  defp register(
         {:unsubscribe, %Subscription{reference: subscription_reference}},
         from,
         %__MODULE__{
           request_id_to_registration: request_id_to_registration,
           subscription_reference_to_subscription_id: subscription_reference_to_subscription_id
         } = state
       ) do
    case subscription_reference_to_subscription_id do
      %{^subscription_reference => subscription_id} ->
        unique_id = unique_request_id(state)
        request = request(%{id: unique_id, method: "eth_unsubscribe", params: [subscription_id]})

        {
          :ok,
          request,
          %__MODULE__{
            state
            | request_id_to_registration:
                Map.put(request_id_to_registration, unique_id, %Registration{
                  from: from,
                  type: :unsubscribe,
                  request: request
                })
          }
        }

      _ ->
        {:error, :not_found}
    end
  end

  defp rerequest(%__MODULE__{request_id_to_registration: request_id_to_registration} = state) do
    Enum.each(request_id_to_registration, fn {_, %Registration{request: request}} ->
      :websocket_client.cast(self(), frame(request))
    end)

    state
  end

  defp respond_to_registration(
         %Registration{type: :json_rpc, from: from},
         response,
         %__MODULE__{} = state
       ) do
    reply =
      case response do
        %{"result" => result} -> {:ok, result}
        %{"error" => error} -> {:error, error}
      end

    GenServer.reply(from, reply)

    {:ok, state}
  end

  defp respond_to_registration(
         %Registration{
           type: :subscribe,
           from: {subscriber_pid, from_reference} = from,
           request: %{params: [event | params]}
         },
         %{"result" => subscription_id},
         %__MODULE__{
           subscription_id_to_subscription_reference: subscription_id_to_subscription_reference,
           subscription_reference_to_subscription: subscription_reference_to_subscription,
           subscription_reference_to_subscription_id: subscription_reference_to_subscription_id,
           url: url
         } = state
       ) do
    new_state =
      case subscription_reference_to_subscription do
        # resubscribe
        %{
          ^from_reference => %Subscription{
            subscriber_pid: ^subscriber_pid,
            transport_options: %WebSocket{
              web_socket: __MODULE__,
              web_socket_options: %Options{event: ^event, params: ^params}
            }
          }
        } ->
          %__MODULE__{
            state
            | subscription_id_to_subscription_reference:
                Map.put(subscription_id_to_subscription_reference, subscription_id, from_reference),
              subscription_reference_to_subscription_id:
                Map.put(subscription_reference_to_subscription_id, from_reference, subscription_id)
          }

        # new subscription
        _ ->
          subscription_reference = make_ref()

          subscription = %Subscription{
            reference: subscription_reference,
            subscriber_pid: subscriber_pid,
            transport: EthereumJSONRPC.WebSocket,
            transport_options: %EthereumJSONRPC.WebSocket{
              web_socket: __MODULE__,
              web_socket_options: %Options{web_socket: self(), event: event, params: params},
              url: url
            }
          }

          GenServer.reply(from, {:ok, subscription})

          %__MODULE__{
            state
            | subscription_reference_to_subscription:
                Map.put(subscription_reference_to_subscription, subscription_reference, subscription),
              subscription_id_to_subscription_reference:
                Map.put(subscription_id_to_subscription_reference, subscription_id, subscription_reference),
              subscription_reference_to_subscription_id:
                Map.put(subscription_reference_to_subscription_id, subscription_reference, subscription_id)
          }
      end

    {:ok, new_state}
  end

  defp respond_to_registration(
         %Registration{type: :subscribe, from: from},
         %{"error" => error},
         %__MODULE__{} = state
       ) do
    GenServer.reply(from, {:error, error})

    {:ok, state}
  end

  defp respond_to_registration(
         %Registration{
           type: :unsubscribe,
           from: from,
           request: %{method: "eth_unsubscribe", params: [subscription_id]}
         },
         response,
         %__MODULE__{
           subscription_id_to_subscription_reference: subscription_id_to_subscription_reference,
           subscription_reference_to_subscription: subscription_reference_to_subscription,
           subscription_reference_to_subscription_id: subscription_reference_to_subscription_id
         } = state
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
      case subscription_id_to_subscription_reference do
        %{^subscription_id => subscription_reference} ->
          %__MODULE__{
            state
            | subscription_id_to_subscription_reference:
                Map.delete(subscription_id_to_subscription_reference, subscription_id),
              subscription_reference_to_subscription:
                Map.delete(subscription_reference_to_subscription, subscription_reference),
              subscription_reference_to_subscription_id:
                Map.delete(subscription_reference_to_subscription_id, subscription_reference)
          }

        _ ->
          state
      end

    {:ok, new_state}
  end

  defp respond_to_registration(
         nil,
         response,
         %__MODULE__{request_id_to_registration: request_id_to_registration} = state
       ) do
    Logger.error(fn ->
      [
        "Got response for unregistered request ID: ",
        inspect(response),
        ".  Outstanding request registrations: ",
        inspect(request_id_to_registration)
      ]
    end)

    {:ok, state}
  end

  defp resubscribe(
         %__MODULE__{subscription_reference_to_subscription: subscription_reference_to_subscription} = initial_state
       ) do
    Enum.reduce(subscription_reference_to_subscription, initial_state, fn {subscription_reference,
                                                                           %Subscription{
                                                                             subscriber_pid: subscriber_pid,
                                                                             transport_options: %WebSocket{
                                                                               web_socket: __MODULE__,
                                                                               web_socket_options: %Options{
                                                                                 event: event,
                                                                                 params: params
                                                                               }
                                                                             }
                                                                           }},
                                                                          %__MODULE__{
                                                                            request_id_to_registration:
                                                                              acc_request_id_to_registration
                                                                          } = acc_state ->
      request_id = unique_request_id(acc_state)
      request = request(%{id: request_id, method: "eth_subscribe", params: [event | params]})

      :websocket_client.cast(self(), frame(request))

      %__MODULE__{
        acc_state
        | request_id_to_registration:
            Map.put(acc_request_id_to_registration, request_id, %Registration{
              from: {subscriber_pid, subscription_reference},
              type: :subscribe,
              request: request
            })
      }
    end)
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
