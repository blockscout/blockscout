defmodule Indexer.Fetcher.OnDemand.ContractCode do
  @moduledoc """
  Ensures that we have a smart-contract bytecode indexed.
  """

  require Logger

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  import EthereumJSONRPC, only: [fetch_codes: 2]

  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Counters.Helper
  alias Explorer.Utility.AddressContractCodeFetchAttempt

  @max_delay :timer.hours(168)

  @spec trigger_fetch(Hash.Address.t()) :: :ok
  def trigger_fetch(address_hash) do
    GenServer.cast(__MODULE__, {:fetch, address_hash})
  end

  defp fetch_contract_code(address_hash, state) do
    with {:retries_number, {retries_number, updated_at}} <-
           {:retries_number, AddressContractCodeFetchAttempt.get_retries_number(address_hash)},
         updated_at_ms = DateTime.to_unix(updated_at, :millisecond),
         {:retry, true} <-
           {:retry,
            Helper.current_time() - updated_at_ms > min(:math.pow(update_threshold(), retries_number), @max_delay)} do
      fetch_and_broadcast_bytecode(address_hash, state)
    else
      {:retries_number, nil} ->
        fetch_and_broadcast_bytecode(address_hash, state)
        :ok

      {:retry, false} ->
        :ok
    end
  end

  defp fetch_and_broadcast_bytecode(address_hash, state) do
    with {:ok, %EthereumJSONRPC.FetchedCodes{params_list: fetched_codes}} <-
           fetch_codes(
             [%{block_quantity: "latest", address: to_string(address_hash)}],
             state.json_rpc_named_arguments
           ),
         contract_code_object = List.first(fetched_codes),
         false <- is_nil(contract_code_object),
         true <- contract_code_object.code !== "0x" do
      case Address.set_contract_code(address_hash, contract_code_object.code) do
        {1, _} ->
          AddressContractCodeFetchAttempt.delete_address_contract_code_fetch_attempt(address_hash)
          Publisher.broadcast(%{fetched_bytecode: [address_hash, contract_code_object.code]}, :on_demand)

        _ ->
          Logger.error(fn -> "Error while setting address #{inspect(to_string(address_hash))} deployed bytecode" end)
      end
    else
      _ ->
        AddressContractCodeFetchAttempt.insert_retries_number(address_hash)
    end
  end

  def start_link([init_opts, server_opts]) do
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @impl true
  def init(json_rpc_named_arguments) do
    {:ok, %{json_rpc_named_arguments: json_rpc_named_arguments}}
  end

  @impl true
  def handle_cast({:fetch, address_hash}, state) do
    fetch_contract_code(address_hash, state)

    {:noreply, state}
  end

  defp update_threshold do
    Application.get_env(:indexer, __MODULE__)[:threshold]
  end
end
