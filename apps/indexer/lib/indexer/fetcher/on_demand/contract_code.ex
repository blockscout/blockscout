defmodule Indexer.Fetcher.OnDemand.ContractCode do
  @moduledoc """
  Ensures that we have a smart-contract bytecode indexed.
  """

  require Logger

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  import EthereumJSONRPC, only: [fetch_codes: 2]

  alias Explorer.Chain.Address
  alias Explorer.Chain.Cache.Counters.Helper
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Utility.AddressContractCodeFetchAttempt

  @max_delay :timer.hours(168)

  @spec trigger_fetch(Address.t()) :: :ok
  def trigger_fetch(address) do
    if is_nil(address.contract_code) do
      GenServer.cast(__MODULE__, {:fetch, address})
    end
  end

  # Attempts to fetch the contract code for a given address.
  #
  # This function checks if the contract code needs to be fetched and if enough time
  # has passed since the last attempt. If conditions are met, it triggers the fetch
  # and broadcast process.
  #
  # ## Parameters
  #   address: The address of the contract.
  #   state: The current state of the fetcher, containing JSON-RPC configuration.
  #
  # ## Returns
  #   `:ok` in all cases.
  @spec fetch_contract_code(Address.t(), %{
          json_rpc_named_arguments: EthereumJSONRPC.json_rpc_named_arguments()
        }) :: :ok
  defp fetch_contract_code(address, state) do
    with {:need_to_fetch, true} <- {:need_to_fetch, fetch?(address)},
         {:retries_number, {retries_number, updated_at}} <-
           {:retries_number, AddressContractCodeFetchAttempt.get_retries_number(address.hash)},
         updated_at_ms = DateTime.to_unix(updated_at, :millisecond),
         {:retry, true} <-
           {:retry,
            Helper.current_time() - updated_at_ms >
              threshold(retries_number)} do
      fetch_and_broadcast_bytecode(address.hash, state)
    else
      {:need_to_fetch, false} ->
        :ok

      {:retries_number, nil} ->
        fetch_and_broadcast_bytecode(address.hash, state)
        :ok

      {:retry, false} ->
        :ok
    end
  end

  # Determines if contract code should be fetched for an address
  @spec fetch?(Address.t()) :: boolean()
  defp fetch?(address) when is_nil(address.nonce), do: true
  # if the address has a signed authorization, it might have a bytecode
  # according to EIP-7702
  defp fetch?(%{signed_authorization: %{authority: _}}), do: true
  defp fetch?(_), do: false

  # Fetches and broadcasts the bytecode for a given address.
  #
  # This function attempts to retrieve the contract bytecode for the specified address
  # using the Ethereum JSON-RPC API. If successful, it updates the database as described below
  # and broadcasts the result:
  # 1. Updates the `addresses` table with the contract code if fetched successfully.
  # 2. Modifies the `address_contract_code_fetch_attempts` table:
  #    - Deletes the entry if the code is successfully set.
  #    - Increments the retry count if the fetch fails or returns empty code.
  # 3. Broadcasts a message with the fetched bytecode if successful.
  #
  # ## Parameters
  #   address_hash: The `t:Explorer.Chain.Hash.Address.t/0` of the contract.
  #   state: The current state of the fetcher, containing JSON-RPC configuration.
  #
  # ## Returns
  #   `:ok` (the function always returns `:ok`, actual results are handled via side effects)
  @spec fetch_and_broadcast_bytecode(Explorer.Chain.Hash.Address.t(), %{
          json_rpc_named_arguments: EthereumJSONRPC.json_rpc_named_arguments()
        }) :: :ok
  defp fetch_and_broadcast_bytecode(address_hash, %{json_rpc_named_arguments: _} = state) do
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

  # An initial threshold to fetch smart-contract bytecode on-demand
  @spec update_threshold_ms() :: non_neg_integer()
  defp update_threshold_ms do
    Application.get_env(:indexer, __MODULE__)[:threshold]
  end

  # Calculates the delay for the next fetch attempt based on the number of retries
  @spec threshold(non_neg_integer()) :: non_neg_integer()
  defp threshold(retries_number) do
    delay_in_ms = trunc(update_threshold_ms() * :math.pow(2, retries_number))

    min(delay_in_ms, @max_delay)
  end
end
