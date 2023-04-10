defmodule EthereumJSONRPC.Utility.EndpointAvailabilityObserver do
  @moduledoc """
  Stores and updates the availability of endpoints
  """

  use GenServer

  alias EthereumJSONRPC.Utility.EndpointAvailabilityChecker

  @max_error_count 3
  @window_duration 3
  @cleaning_interval :timer.seconds(1)

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    schedule_next_cleaning()

    {:ok, %{error_counts: %{}, unavailable_endpoints: []}}
  end

  def inc_error_count(url, json_rpc_named_arguments) do
    GenServer.cast(__MODULE__, {:inc_error_count, url, json_rpc_named_arguments})
  end

  def check_endpoint(url) do
    GenServer.call(__MODULE__, {:check_endpoint, url})
  end

  def enable_endpoint(url) do
    GenServer.cast(__MODULE__, {:enable_endpoint, url})
  end

  def handle_call({:check_endpoint, url}, _from, %{unavailable_endpoints: unavailable_endpoints} = state) do
    result = if url in unavailable_endpoints, do: :unavailable, else: :ok

    {:reply, result, state}
  end

  def handle_cast({:inc_error_count, url, json_rpc_named_arguments}, %{error_counts: error_counts} = state) do
    current_count = error_counts[url][:count]
    unavailable_endpoints = state.unavailable_endpoints

    new_state =
      cond do
        url in unavailable_endpoints ->
          state

        is_nil(current_count) ->
          %{state | error_counts: Map.put(error_counts, url, %{count: 1, last_occasion: now()})}

        current_count + 1 >= @max_error_count ->
          EndpointAvailabilityChecker.add_endpoint(put_in(json_rpc_named_arguments[:transport_options][:url], url))
          %{state | error_counts: Map.delete(error_counts, url), unavailable_endpoints: [url | unavailable_endpoints]}

        true ->
          %{state | error_counts: Map.put(error_counts, url, %{count: current_count + 1, last_occasion: now()})}
      end

    {:noreply, new_state}
  end

  def handle_cast({:enable_endpoint, url}, %{unavailable_endpoints: unavailable_endpoints} = state) do
    {:noreply, %{state | unavailable_endpoints: unavailable_endpoints -- [url]}}
  end

  def handle_info(:clear_old_records, %{error_counts: error_counts} = state) do
    new_error_counts =
      Enum.reduce(error_counts, %{}, fn {url, %{last_occasion: last_occasion} = record}, acc ->
        if now() - last_occasion > @window_duration, do: acc, else: Map.put(acc, url, record)
      end)

    schedule_next_cleaning()

    {:noreply, %{state | error_counts: new_error_counts}}
  end

  defp schedule_next_cleaning do
    Process.send_after(self(), :clear_old_records, @cleaning_interval)
  end

  defp now, do: :os.system_time(:second)
end
