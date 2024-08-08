defmodule EthereumJSONRPC.WebSocket.WebSocketClient do
  @moduledoc """
  `EthereumJSONRPC.WebSocket` that uses `WebSockex`
  """

  require Logger

  alias EthereumJSONRPC.{Subscription, Transport, WebSocket}
  alias EthereumJSONRPC.WebSocket.{Registration, RetryWorker}
  alias EthereumJSONRPC.WebSocket.Supervisor, as: WebSocketSupervisor
  alias EthereumJSONRPC.WebSocket.WebSocketClient.Options

  @behaviour WebSocket

  @enforce_keys ~w(url)a
  defstruct connected: false,
            request_id_to_registration: %{},
            subscription_id_to_subscription_reference: %{},
            subscription_reference_to_subscription_id: %{},
            subscription_reference_to_subscription: %{},
            url: nil,
            fallback?: false,
            fallback_url: nil,
            fallback_conn: nil,
            retry: false

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

  @impl WebSocket
  def child_spec(arg) do
    Supervisor.child_spec(%{id: __MODULE__, start: {__MODULE__, :start_link, [arg]}}, [])
  end

  @impl WebSocket
  def start_link(url, options) do
    case build_conn(url, options) do
      {:ok, conn, opts} ->
        init_state =
          options[:init_state] ||
            %__MODULE__{
              url: url,
              fallback_url: options[:fallback_url],
              fallback_conn: build_fallback_conn(options[:fallback_url], options)
            }

        WebSockex.start_link(conn, __MODULE__, init_state, opts)

      error ->
        Logger.error("Unable to build WS main connection: #{inspect(error)}")
        :ignore
    end
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

  def handle_connect(_conn, state) do
    Logger.metadata(fetcher: :websocket_client)

    unless state.fallback? do
      RetryWorker.deactivate()
      WebSocketSupervisor.stop_other_client(self())
    end

    {:ok, reconnect(%{state | connected: true, retry: false})}
  end

  def handle_disconnect(_, %{retry: true} = state) do
    Logger.metadata(fetcher: :websocket_client)
    RetryWorker.activate(state)
    Logger.warning("WS endpoint #{state.url} is still unavailable")
    {:ok, state}
  end

  @attempts_to_reconnect 3
  def handle_disconnect(%{attempt_number: attempt}, state) do
    Logger.metadata(fetcher: :websocket_client)

    final_state =
      state.request_id_to_registration
      |> Enum.reduce(state, &disconnect_request_id_registration/2)
      |> Map.put(:connected, false)

    cond do
      attempt < @attempts_to_reconnect ->
        {:reconnect, final_state}

      state.fallback? ->
        Logger.warning("WS fallback endpoint #{state.fallback_url} is unavailable")
        {:ok, final_state}

      not is_nil(state.fallback_conn) ->
        RetryWorker.activate(state)
        Logger.warning("WS endpoint #{state.url} is unavailable, switching to fallback #{state.fallback_url}")

        {:reconnect, state.fallback_conn,
         %{final_state | url: state.fallback_url, fallback?: true, fallback_url: nil, fallback_conn: nil}}

      true ->
        RetryWorker.activate(state)
        Logger.warning("WS endpoint #{state.url} is unavailable, and no fallback is set, shutting down WS client")
        {:ok, final_state}
    end
  end

  def handle_frame({:text, text}, state) do
    case Jason.decode(text) do
      {:ok, json} ->
        handle_response(json, state)

      {:error, _} = error ->
        broadcast(error, state)
        {:ok, state}
    end
  end

  def handle_ping({:ping, ""}, state) do
    {:reply, {:pong, ""}, state}
  end

  def handle_pong({:pong, _}, state) do
    {:ok, state}
  end

  def handle_info({:"$gen_call", from, request}, state) do
    case register(request, from, state) do
      {:ok, unique_request, updated_state} ->
        case state.connected do
          true ->
            {:reply, frame(unique_request), updated_state}

          false ->
            {:ok, updated_state}
        end

      {:error, _reason} = error ->
        GenServer.reply(from, error)
        {:ok, state}
    end
  end

  def handle_cast({:send_message, frame}, state) do
    {:reply, frame, state}
  end

  def terminate(reason, state) do
    broadcast(reason, state)
  end

  defp build_conn(url, options) when is_binary(url) do
    common_opts = [
      name: options[:name] || __MODULE__,
      async: true,
      handle_initial_conn_failure: true
    ]

    additional_opts =
      case url do
        "wss://" <> _ ->
          %URI{host: host} = URI.parse(url)
          host_charlist = String.to_charlist(host)

          :ssl.start()

          [
            insecure: false,
            ssl_options: [
              cacerts: :certifi.cacerts(),
              depth: 99,
              # SNI extension discloses host name in the clear, but allows for compatibility with Virtual Hosting for TLS
              server_name_indication: host_charlist,
              verify_fun: {&:ssl_verify_hostname.verify_fun/3, [check_hostname: host_charlist]},
              customize_hostname_check: [
                match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
              ]
            ]
          ]

        _ ->
          []
      end

    full_opts = Keyword.merge(common_opts, additional_opts)

    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    case WebSockex.Conn.parse_url(url) do
      # credo:disable-for-next-line Credo.Check.Design.AliasUsage
      {:ok, uri} -> {:ok, WebSockex.Conn.new(uri, full_opts), full_opts}
      error -> error
    end
  end

  defp build_fallback_conn(nil, _options) do
    Logger.info("WS fallback endpoint is not set")
    nil
  end

  defp build_fallback_conn(url, options) do
    case build_conn(url, options) do
      {:ok, conn, _opts} ->
        conn

      error ->
        Logger.warning("Unable to build WS fallback connection: #{inspect(error)}, continuing without fallback")
        nil
    end
  end

  defp broadcast(message, %__MODULE__{subscription_reference_to_subscription: subscription_reference_to_subscription}) do
    subscription_reference_to_subscription
    |> Map.values()
    |> Subscription.broadcast(message)
  end

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

  defp disconnect_request_id_registration({_request_id, %Registration{type: type}}, state)
       when type in ~w(json_rpc subscribe)a do
    state
  end

  defp frame(request) do
    {:text, Jason.encode!(request)}
  end

  defp handle_response(
         %{"method" => "eth_subscription", "params" => %{"result" => result, "subscription" => subscription_id}},
         %{
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
         %{request_id_to_registration: request_id_to_registration} = state
       ) do
    {registration, new_request_id_to_registration} = Map.pop(request_id_to_registration, id)
    new_state = %{state | request_id_to_registration: new_request_id_to_registration}

    respond_to_registration(registration, response, new_state)
  end

  defp handle_response(response, state) do
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

  defp reconnect(state) do
    state
    |> rerequest()
    |> resubscribe()
  end

  defp register(
         {:json_rpc, original_request},
         from,
         %{request_id_to_registration: request_id_to_registration} = state
       ) do
    unique_id = unique_request_id(state)
    request = %{original_request | id: unique_id}

    {:ok, request,
     %{
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
         %{request_id_to_registration: request_id_to_registration} = state
       )
       when is_binary(event) and is_list(params) do
    unique_id = unique_request_id(state)
    request = EthereumJSONRPC.request(%{id: unique_id, method: "eth_subscribe", params: [event | params]})

    {:ok, request,
     %{
       state
       | request_id_to_registration:
           Map.put(request_id_to_registration, unique_id, %Registration{from: from, type: :subscribe, request: request})
     }}
  end

  defp register(
         {:unsubscribe, %Subscription{reference: subscription_reference}},
         from,
         %{
           request_id_to_registration: request_id_to_registration,
           subscription_reference_to_subscription_id: subscription_reference_to_subscription_id
         } = state
       ) do
    case subscription_reference_to_subscription_id do
      %{^subscription_reference => subscription_id} ->
        unique_id = unique_request_id(state)
        request = EthereumJSONRPC.request(%{id: unique_id, method: "eth_unsubscribe", params: [subscription_id]})

        {
          :ok,
          request,
          %{
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
      WebSockex.cast(self(), {:send_message, frame(request)})
    end)

    state
  end

  defp respond_to_registration(
         %Registration{type: :json_rpc, from: from},
         response,
         state
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
         %{
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
         state
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
         %{
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
         %{request_id_to_registration: request_id_to_registration} = state
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
      request = EthereumJSONRPC.request(%{id: request_id, method: "eth_subscribe", params: [event | params]})

      WebSockex.cast(self(), {:send_message, frame(request)})

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

  defp unique_request_id(%{request_id_to_registration: request_id_to_registration} = state) do
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
