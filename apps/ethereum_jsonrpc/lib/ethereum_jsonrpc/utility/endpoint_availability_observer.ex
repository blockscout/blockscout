defmodule EthereumJSONRPC.Utility.EndpointAvailabilityObserver do
  @moduledoc """
  Stores and updates the availability of endpoints
  """

  use GenServer

  require Logger

  alias EthereumJSONRPC.Utility.{CommonHelper, EndpointAvailabilityChecker}

  @max_error_count 3
  @window_duration 3
  @cleaning_interval :timer.seconds(1)

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    schedule_next_cleaning()

    {:ok, %{error_counts: %{}, unavailable_endpoints: %{ws: [], trace: [], http: [], eth_call: []}}}
  end

  def inc_error_count(url, json_rpc_named_arguments, url_type) do
    GenServer.cast(__MODULE__, {:inc_error_count, url, json_rpc_named_arguments, url_type})
  end

  def check_endpoint(url, url_type) do
    GenServer.call(__MODULE__, {:check_endpoint, url, url_type})
  end

  def filter_unavailable_urls(urls, url_type) do
    GenServer.call(__MODULE__, {:filter_unavailable_urls, urls, url_type})
  end

  def maybe_replace_url(url, replace_url, url_type) do
    case check_endpoint(url, url_type) do
      :ok -> url
      :unavailable -> replace_url || url
    end
  end

  def maybe_replace_urls(urls, replace_urls, url_type) do
    case filter_unavailable_urls(urls, url_type) do
      [] -> replace_urls || urls || []
      available_urls -> available_urls
    end
  end

  def enable_endpoint(url, url_type, json_rpc_named_arguments) do
    GenServer.cast(__MODULE__, {:enable_endpoint, url, url_type, json_rpc_named_arguments})
  end

  def handle_call({:check_endpoint, url, url_type}, _from, %{unavailable_endpoints: unavailable_endpoints} = state) do
    result = if url in unavailable_endpoints[url_type], do: :unavailable, else: :ok

    {:reply, result, state}
  end

  def handle_call(
        {:filter_unavailable_urls, urls, url_type},
        _from,
        %{unavailable_endpoints: unavailable_endpoints} = state
      ) do
    {:reply, do_filter_unavailable_urls(urls, unavailable_endpoints[url_type]), state}
  end

  def handle_cast({:inc_error_count, url, json_rpc_named_arguments, url_type}, state) do
    new_state =
      if json_rpc_named_arguments[:api?],
        do: state,
        else: do_increase_error_counts(url, json_rpc_named_arguments, url_type, state)

    {:noreply, new_state}
  end

  def handle_cast(
        {:enable_endpoint, url, url_type, json_rpc_named_arguments},
        %{unavailable_endpoints: unavailable_endpoints} = state
      ) do
    log_url_available(url, url_type, unavailable_endpoints, json_rpc_named_arguments)

    {:noreply,
     %{state | unavailable_endpoints: %{unavailable_endpoints | url_type => unavailable_endpoints[url_type] -- [url]}}}
  end

  def handle_info(:clear_old_records, %{error_counts: error_counts} = state) do
    new_error_counts = Enum.reduce(error_counts, %{}, &do_clear_old_records/2)

    schedule_next_cleaning()

    {:noreply, %{state | error_counts: new_error_counts}}
  end

  defp do_clear_old_records({url, counts_by_types}, acc) do
    counts_by_types
    |> Enum.reduce(%{}, fn {type, %{last_occasion: last_occasion} = record}, acc ->
      if now() - last_occasion > @window_duration, do: acc, else: Map.put(acc, type, record)
    end)
    |> case do
      empty_map when empty_map == %{} -> acc
      non_empty_map -> Map.put(acc, url, non_empty_map)
    end
  end

  defp do_filter_unavailable_urls(urls, unavailable_urls) do
    Enum.reject(urls || [], fn url -> url in unavailable_urls end)
  end

  defp do_increase_error_counts(url, json_rpc_named_arguments, url_type, %{error_counts: error_counts} = state) do
    current_count = error_counts[url][url_type][:count]
    unavailable_endpoints = state.unavailable_endpoints[url_type]

    cond do
      url in unavailable_endpoints ->
        state

      is_nil(current_count) ->
        %{state | error_counts: Map.put(error_counts, url, %{url_type => %{count: 1, last_occasion: now()}})}

      current_count + 1 >= @max_error_count ->
        EndpointAvailabilityChecker.add_endpoint(
          put_in(json_rpc_named_arguments[:transport_options][:url], url),
          url_type
        )

        log_url_unavailable(url, url_type, unavailable_endpoints, json_rpc_named_arguments)

        %{
          state
          | error_counts: Map.put(error_counts, url, Map.delete(error_counts[url], url_type)),
            unavailable_endpoints: %{state.unavailable_endpoints | url_type => [url | unavailable_endpoints]}
        }

      true ->
        %{
          state
          | error_counts: Map.put(error_counts, url, %{url_type => %{count: current_count + 1, last_occasion: now()}})
        }
    end
  end

  defp log_url_unavailable(url, :ws, _unavailable_endpoints, _json_rpc_named_arguments) do
    Logger.warning("URL #{inspect(url)} is unavailable")
  end

  defp log_url_unavailable(url, url_type, unavailable_endpoints, json_rpc_named_arguments) do
    available_urls =
      url_type
      |> available_urls(unavailable_endpoints, json_rpc_named_arguments)
      |> Kernel.--([url])

    fallback_url_message =
      case {available_urls, fallback_url_set?(url_type, json_rpc_named_arguments)} do
        {[], true} -> "and there is no other #{url_type} url available, switching to fallback #{url_type} url"
        {[], false} -> "there is no other #{url_type} url available, and no fallback is set"
        _ -> "switching to another #{url_type} url"
      end

    Logger.warning("URL #{inspect(url)} is unavailable, #{fallback_url_message}")
  end

  defp log_url_available(url, url_type, unavailable_endpoints, json_rpc_named_arguments) do
    available_urls = available_urls(url_type, unavailable_endpoints, json_rpc_named_arguments)

    message_extra =
      case {available_urls, fallback_url_set?(url_type, json_rpc_named_arguments)} do
        {[], true} -> ", switching back from fallback urls"
        _ -> ""
      end

    Logger.info("URL #{inspect(url)} of #{url_type} type is available now#{message_extra}")
  end

  defp available_urls(url_type, unavailable_endpoints, json_rpc_named_arguments) do
    url_type
    |> CommonHelper.url_type_to_urls(json_rpc_named_arguments[:transport_options])
    |> do_filter_unavailable_urls(unavailable_endpoints)
  end

  defp fallback_url_set?(url_type, json_rpc_named_arguments) do
    case url_type do
      :http -> not is_nil(json_rpc_named_arguments[:transport_options][:fallback_urls])
      :trace -> not is_nil(json_rpc_named_arguments[:transport_options][:fallback_trace_urls])
      :eth_call -> not is_nil(json_rpc_named_arguments[:transport_options][:fallback_eth_call_urls])
      _ -> false
    end
  end

  defp schedule_next_cleaning do
    Process.send_after(self(), :clear_old_records, @cleaning_interval)
  end

  defp now, do: :os.system_time(:second)
end
