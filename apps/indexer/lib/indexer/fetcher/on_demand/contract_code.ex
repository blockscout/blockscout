defmodule Indexer.Fetcher.OnDemand.ContractCode do
  @moduledoc """
  Ensures that we have a smart-contract bytecode indexed.
  """

  require Logger

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  import EthereumJSONRPC, only: [fetch_codes: 2]

  alias Explorer.Chain.Address
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Counters.Helper
  alias Explorer.Utility.AddressContractCodeFetchAttempt

  @max_delay :timer.hours(168)

  @spec trigger_fetch(Address.t()) :: :ok
  def trigger_fetch(address) do
    if is_nil(address.contract_code) do
      GenServer.cast(__MODULE__, {:fetch, address})
    end
  end

  defp fetch_contract_code(address, state) do
    with {:empty_nonce, true} <- {:empty_nonce, is_nil(address.nonce)},
         {:retries_number, {retries_number, updated_at}} <-
           {:retries_number, AddressContractCodeFetchAttempt.get_retries_number(address.hash)},
         updated_at_ms = DateTime.to_unix(updated_at, :millisecond),
         {:retry, true} <-
           {:retry,
            Helper.current_time() - updated_at_ms >
              threshold(retries_number)} do
      fetch_and_broadcast_bytecode(address.hash, state)
    else
      {:empty_nonce, false} ->
        :ok

      {:retries_number, nil} ->
        fetch_and_broadcast_bytecode(address.hash, state)
        :ok

      {:retry, false} ->
        :ok
    end
  end

  defp fetch_and_broadcast_bytecode(address_hash, state) do
    with {:fetched_code, {:ok, %EthereumJSONRPC.FetchedCodes{params_list: fetched_codes}}} <-
           {:fetched_code,
            fetch_codes(
              [%{block_quantity: "latest", address: to_string(address_hash)}],
              state.json_rpc_named_arguments
            )},
         contract_code_object = List.first(fetched_codes),
         false <- is_nil(contract_code_object),
         true <- contract_code_object.code !== "0x" do
      case Address.set_contract_code(address_hash, contract_code_object.code) do
        {1, _} ->
          AddressContractCodeFetchAttempt.delete(address_hash)
          Publisher.broadcast(%{fetched_bytecode: [address_hash, contract_code_object.code]}, :on_demand)

        _ ->
          Logger.error(fn -> "Error while setting address #{inspect(to_string(address_hash))} deployed bytecode" end)
      end
    else
      {:fetched_code, {:error, _}} ->
        :ok

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
  def handle_cast({:fetch, address}, state) do
    fetch_contract_code(address, state)

    {:noreply, state}
  end

  defp update_threshold_ms do
    Application.get_env(:indexer, __MODULE__)[:threshold]
  end

  defp threshold(retries_number) do
    delay_in_ms = trunc(update_threshold_ms() * :math.pow(2, retries_number))

    min(delay_in_ms, @max_delay)
  end
end
