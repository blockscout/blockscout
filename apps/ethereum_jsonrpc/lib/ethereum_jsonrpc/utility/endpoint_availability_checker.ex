defmodule EthereumJSONRPC.Utility.EndpointAvailabilityChecker do
  @moduledoc """
  Performs actual endpoint checks
  """

  use GenServer

  alias EthereumJSONRPC.Utility.EndpointAvailabilityObserver

  @check_interval :timer.seconds(1)

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    schedule_next_check()

    {:ok, %{unavailable_endpoints_arguments: []}}
  end

  def add_endpoint(json_rpc_named_arguments) do
    GenServer.cast(__MODULE__, {:add_endpoint, json_rpc_named_arguments})
  end

  def handle_cast({:add_endpoint, named_arguments}, %{unavailable_endpoints_arguments: unavailable} = state) do
    {:noreply, %{state | unavailable_endpoints_arguments: [named_arguments | unavailable]}}
  end

  def handle_info(:check, %{unavailable_endpoints_arguments: unavailable_endpoints_arguments} = state) do
    new_unavailable_endpoints =
      Enum.reduce(unavailable_endpoints_arguments, [], fn json_rpc_named_arguments, acc ->
        case fetch_latest_block_number(json_rpc_named_arguments) do
          {:ok, _number} ->
            EndpointAvailabilityObserver.enable_endpoint(json_rpc_named_arguments[:transport_options][:url])
            acc

          _ ->
            [json_rpc_named_arguments | acc]
        end
      end)

    schedule_next_check()

    {:noreply, %{state | unavailable_endpoints_arguments: new_unavailable_endpoints}}
  end

  defp fetch_latest_block_number(json_rpc_named_arguments) do
    {_, arguments_without_fallback} = pop_in(json_rpc_named_arguments, [:transport_options, :fallback_url])

    %{id: 0, method: "eth_blockNumber", params: []}
    |> EthereumJSONRPC.request()
    |> EthereumJSONRPC.json_rpc(arguments_without_fallback)
  end

  defp schedule_next_check do
    Process.send_after(self(), :check, @check_interval)
  end
end
