defmodule EthereumJSONRPC.Utility.EndpointAvailabilityChecker do
  @moduledoc """
  Monitors and verifies the availability of Ethereum JSON-RPC endpoints.

  This GenServer-based module performs periodic checks on endpoints that have been marked
  as unavailable, attempting to re-enable them when they become responsive again.

  ## State Structure

  The GenServer maintains state with the following structure:

      %{
        unavailable_endpoints_arguments: [
          {json_rpc_named_arguments, url_type},
          ...
        ]
      }

  where:
  - `unavailable_endpoints_arguments`: List of tuples containing endpoint configurations
    and their types that are currently marked as unavailable
  - `json_rpc_named_arguments`: JSON-RPC configuration for the endpoint
  - `url_type`: Type of the endpoint (`:ws`, `:trace`, `:http`, or `:eth_call`)

  ## Usage

  This module is designed to work in conjunction with `EthereumJSONRPC.Utility.EndpointAvailabilityObserver`.
  When an endpoint exceeds its error threshold in the observer, it is automatically added here for monitoring:

      # In EndpointAvailabilityObserver, when errors exceed threshold:
      json_rpc_config = [
        transport: EthereumJSONRPC.HTTP,
        transport_options: [
          urls: ["http://localhost:8545"]
        ]
      ]
      EndpointAvailabilityChecker.add_endpoint(json_rpc_config, :http)

  ## State Changes

  The state changes in the following scenarios:

  1. When an endpoint is added via `add_endpoint/2`:
     - The endpoint is added to `unavailable_endpoints_arguments`

  2. During periodic checks:
     - Successfully checked endpoints are removed from `unavailable_endpoints_arguments`
     - Failed endpoints remain in the list for the next check
  """

  use GenServer

  require Logger

  alias EthereumJSONRPC.Utility.EndpointAvailabilityObserver

  @check_interval :timer.seconds(1)

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    if Application.get_env(:ethereum_jsonrpc, __MODULE__)[:enabled] do
      schedule_next_check()

      {:ok, %{unavailable_endpoints_arguments: []}}
    else
      :ignore
    end
  end

  @doc """
    Adds an endpoint to be monitored for availability.

    ## Parameters
    - `json_rpc_named_arguments`: JSON-RPC configuration for the endpoint
    - `url_type`: Type of the endpoint (`:ws`, `:trace`, `:http`, or `:eth_call`)

    ## Returns
    - `:ok`
  """
  @spec add_endpoint(EthereumJSONRPC.json_rpc_named_arguments(), :ws | :trace | :http | :eth_call) :: :ok
  def add_endpoint(json_rpc_named_arguments, url_type) do
    GenServer.cast(__MODULE__, {:add_endpoint, json_rpc_named_arguments, url_type})
  end

  # Handles asynchronous request to add an endpoint for availability monitoring.
  #
  # Adds the endpoint's configuration and type to the list of unavailable
  # endpoints in the state.
  #
  # ## Parameters
  # - `named_arguments`: JSON-RPC configuration for the endpoint
  # - `url_type`: Type of the endpoint
  # - `state`: Current GenServer state
  #
  # ## Returns
  # - `{:noreply, new_state}` with updated list of unavailable endpoints
  def handle_cast({:add_endpoint, named_arguments, url_type}, %{unavailable_endpoints_arguments: unavailable} = state) do
    {:noreply, %{state | unavailable_endpoints_arguments: [{named_arguments, url_type} | unavailable]}}
  end

  # Handles periodic endpoint availability check.
  #
  # Attempts to fetch the latest block number from each unavailable endpoint.
  # If successful, enables the endpoint via `EthereumJSONRPC.Utility.EndpointAvailabilityObserver`.
  # If unsuccessful, keeps the endpoint in the unavailable list.
  #
  # ## Parameters
  # - `state`: Current GenServer state with list of unavailable endpoints
  #
  # ## Returns
  # - `{:noreply, new_state}` with updated list of unavailable endpoints
  def handle_info(:check, %{unavailable_endpoints_arguments: unavailable_endpoints_arguments} = state) do
    new_unavailable_endpoints =
      Enum.reduce(unavailable_endpoints_arguments, [], fn {json_rpc_named_arguments, url_type}, acc ->
        case fetch_latest_block_number(json_rpc_named_arguments) do
          {:ok, _number} ->
            [url] = json_rpc_named_arguments[:transport_options][:urls]

            EndpointAvailabilityObserver.enable_endpoint(url, url_type, json_rpc_named_arguments)
            acc

          _ ->
            [{json_rpc_named_arguments, url_type} | acc]
        end
      end)

    schedule_next_check()

    {:noreply, %{state | unavailable_endpoints_arguments: new_unavailable_endpoints}}
  end

  @doc """
  Retrieves the latest block number from an Ethereum node to check endpoint availability.

  Removes fallback URLs from the arguments to ensure checking only the primary endpoint.

  ## Parameters
  - `json_rpc_named_arguments`: JSON-RPC configuration for the endpoint

  ## Returns
  - `{:ok, number}` if the endpoint is available
  - `{:error, reason}` if the endpoint is unavailable
  """
  @spec fetch_latest_block_number(EthereumJSONRPC.json_rpc_named_arguments()) ::
          {:ok, EthereumJSONRPC.Transport.result()} | {:error, reason :: term()}
  def fetch_latest_block_number(json_rpc_named_arguments) do
    {_, arguments_without_fallback} = pop_in(json_rpc_named_arguments, [:transport_options, :fallback_urls])

    %{id: 0, method: "eth_blockNumber", params: []}
    |> EthereumJSONRPC.request()
    |> EthereumJSONRPC.json_rpc(arguments_without_fallback)
  end

  @spec schedule_next_check() :: reference()
  defp schedule_next_check do
    Process.send_after(self(), :check, @check_interval)
  end
end
