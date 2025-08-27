defmodule Indexer.Fetcher.OnDemand.ContractCode do
  @moduledoc """
  Ensures that we have a smart-contract bytecode indexed.
  """

  require Logger

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  import EthereumJSONRPC, only: [fetch_codes: 2]

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Data, Hash}
  alias Explorer.Chain.Cache.Accounts
  alias Explorer.Chain.Cache.Counters.Helper
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  alias Explorer.Utility.{AddressContractCodeFetchAttempt, RateLimiter}
  alias Indexer.Fetcher.OnDemand.ContractCreator, as: ContractCreatorOnDemand

  @max_delay :timer.hours(168)

  @spec trigger_fetch(String.t() | nil, Address.t()) :: :ok
  def trigger_fetch(caller \\ nil, address) do
    if is_nil(address.contract_code) or Address.eoa_with_code?(address) do
      case RateLimiter.check_rate(caller, :on_demand) do
        :allow -> GenServer.cast(__MODULE__, {:fetch, address})
        :deny -> :ok
      end
    else
      ContractCreatorOnDemand.trigger_fetch(address)
    end
  end

  @doc """
  Checks database for bytecode first, then fetches from RPC if not found.
  This function handles the complete verification flow including database fallback.

  Returns `{:ok, bytecode}` if bytecode is found, or `{:error, :not_a_smart_contract}` otherwise.
  """
  @spec check_and_fetch_bytecode(Hash.Address.t(), Keyword.t()) ::
          {:ok, String.t()} | {:error, :not_a_smart_contract}
  def check_and_fetch_bytecode(address_hash, options \\ []) do
    case Chain.smart_contract_bytecode(address_hash, options) do
      bytecode when bytecode != "0x" and not is_nil(bytecode) ->
        {:ok, bytecode}

      _ ->
        # Bytecode not found in DB, try to fetch it synchronously from RPC
        GenServer.call(__MODULE__, {:check_and_fetch, address_hash, options})
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
      fetch_and_broadcast_bytecode(address, state)
    else
      {:need_to_fetch, false} ->
        :ok

      {:retries_number, nil} ->
        fetch_and_broadcast_bytecode(address, state)
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

  # Extracts the core RPC fetching logic for reuse
  @spec fetch_codes_from_rpc(Address.t(), EthereumJSONRPC.json_rpc_named_arguments()) ::
          {:ok, String.t()} | {:error, any()}
  defp fetch_codes_from_rpc(address, json_rpc_named_arguments) do
    case fetch_codes(
      [%{block_quantity: "latest", address: to_string(address.hash)}],
      json_rpc_named_arguments
    ) do
      {:ok, %EthereumJSONRPC.FetchedCodes{params_list: fetched_codes}} ->
        case Enum.at(fetched_codes, 0) do
          %{code: code} when is_binary(code) ->
            {:ok, code}
          _ ->
            {:error, :no_code}
        end
      {:error, error} ->
        {:error, error}
    end
  end

  @spec fetch_and_broadcast_bytecode(Address.t(), %{
          json_rpc_named_arguments: EthereumJSONRPC.json_rpc_named_arguments()
        }) :: :ok
  defp fetch_and_broadcast_bytecode(address, %{json_rpc_named_arguments: _} = state) do
    with {:fetched_code, {:ok, code}} <-
           {:fetched_code, fetch_codes_from_rpc(address, state.json_rpc_named_arguments)},
         {:ok, fetched_code} <-
           (code == "0x" && {:ok, nil}) || Data.cast(code),
         true <- fetched_code != address.contract_code do
      case Chain.import(%{
             addresses: %{
               params: [%{hash: address.hash, contract_code: fetched_code}],
               on_conflict: {:replace, [:contract_code, :updated_at]},
               fields_to_update: [:contract_code]
             }
           }) do
        {:ok, %{addresses: addresses}} ->
          Accounts.drop(addresses)

          # Update EIP7702 proxy addresses to avoid inconsistencies between addresses and proxy_implementations tables.
          # Other proxy types are not handled here, since their bytecode doesn't change the way EIP7702 bytecode does.
          cond do
            Address.smart_contract?(address) and !Address.eoa_with_code?(address) ->
              :ok

            is_nil(fetched_code) ->
              Implementation.delete_implementations([address.hash])

            true ->
              Implementation.upsert_eip7702_implementations(addresses)
          end

          Publisher.broadcast(%{fetched_bytecode: [address.hash, code]}, :on_demand)

          ContractCreatorOnDemand.trigger_fetch(address)

          AddressContractCodeFetchAttempt.delete(address.hash)
      end
    else
      {:fetched_code, {:error, _}} ->
        :ok

      _ ->
        AddressContractCodeFetchAttempt.insert_retries_number(address.hash)
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

  @impl true
  def handle_call({:check_and_fetch, address_hash, options}, _from, state) do
    case Chain.hash_to_address(address_hash, options) do
      {:ok, address} ->
        # Use the core fetching logic from fetch_and_broadcast_bytecode
        result = case fetch_codes_from_rpc(address, state.json_rpc_named_arguments) do
          {:ok, code} when is_binary(code) and code != "0x" ->
            # Trigger async update for future requests
            trigger_fetch(nil, address)
            {:ok, code}
          {:error, _} ->
            {:error, :not_a_smart_contract}
        end
        {:reply, result, state}

      _ ->
        {:reply, {:error, :not_a_smart_contract}, state}
    end
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
