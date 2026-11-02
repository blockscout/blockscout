# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.OnDemand.ContractCreator do
  @moduledoc """
  Ensures that we have a smart-contract creator address indexed.

  The lookup state is kept in the `:contract_creator_lookup` ETS table:

    * `{address_hash_string, {:in_progress, lookup_ref} | block_number | :not_found, updated_at}` -
      the lookup of the contract creation block of the address is running, has found the block,
      or has found that the address has no creation block (e.g. it is allocated in genesis);
    * `{{:pending_block, block_number}, [address_hash_string]}` - the addresses whose
      contract creation block is waiting to be imported.

  Address entries expire after an hour. The cleanup after block import runs only on the
  node that imports blocks, so on the other nodes an address whose creator is still
  unknown is looked up again once its entry has expired. A lookup can outlive its entry,
  so its result is applied only while the entry still holds the lookup's `lookup_ref`.
  """

  require Logger

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  import EthereumJSONRPC, only: [integer_to_quantity: 1, json_rpc: 2, quantity_to_integer: 1]

  alias EthereumJSONRPC.Nonce
  alias EthereumJSONRPC.Utility.RangesHelper
  alias Explorer.Chain.{Address, Block, PendingOperationsHelper}
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Utility.MissingBlockRange
  alias Indexer.Fetcher.InternalTransaction

  @table_name :contract_creator_lookup
  @max_json_rpc_retries 5
  @entry_ttl :timer.hours(1)
  @sweep_interval :timer.minutes(10)

  def start_link(_) do
    if :ets.whereis(@table_name) == :undefined do
      :ets.new(@table_name, [
        :set,
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec trigger_fetch(Address.t()) :: :ok | :ignore
  def trigger_fetch(address) do
    if :ets.whereis(@table_name) == :undefined do
      Logger.warning(
        "ContractCreator ETS table is not available, skipping on-demand fetch for address #{to_string(address.hash)}"
      )

      :ignore
    else
      do_trigger_fetch(address)
    end
  end

  @spec do_trigger_fetch(Address.t()) :: :ok | :ignore
  defp do_trigger_fetch(address) do
    # we expect here, that address has 'contract_creation_internal_transaction' and 'contract_creation_transaction' preloads
    creation_transaction = Address.creation_transaction(address)
    creator_hash = creation_transaction && creation_transaction.from_address_hash

    with false <- is_nil(address.contract_code),
         true <- is_nil(creator_hash),
         false <- Address.eoa_with_code?(address),
         true <- table_exists?(),
         # neither a running lookup nor a found block waiting for import is restarted until the entry expires
         false <- fresh_entry?(address_cache_name(address.hash)) do
      GenServer.cast(__MODULE__, {:fetch, address})
    else
      _ ->
        :ignore
    end
  end

  @spec fetch_contract_creator_address_hash(Explorer.Chain.Hash.Address.t()) :: non_neg_integer() | :not_found | :error
  defp fetch_contract_creator_address_hash(address_hash) do
    max_block_number = BlockNumber.get_max()

    initial_block_ranges = %{
      left: 0,
      right: max_block_number,
      max: max_block_number
    }

    find_contract_creation_block_number(initial_block_ranges, address_hash, @max_json_rpc_retries)
  catch
    # a crashed lookup must still report a result, otherwise the address stays :in_progress until the entry expires
    kind, reason ->
      Logger.error(
        "Error while looking up contract creation block for address #{to_string(address_hash)}: " <>
          Exception.format(kind, reason, __STACKTRACE__)
      )

      :error
  end

  # A contract gets nonce 1 in the block where it is created (EIP-161) and its nonce never decreases after that,
  # so the creation block is the first block where the address has a nonce. The search keeps it within left..right.
  defp find_contract_creation_block_number(%{left: left, right: right} = block_ranges, address_hash, retries_left)
       when left < right do
    middle = div(left + right, 2)

    case fetch_nonce(address_hash, middle, retries_left) do
      {:ok, 0, retries_left} ->
        find_contract_creation_block_number(%{block_ranges | left: middle + 1}, address_hash, retries_left)

      {:ok, _nonce, retries_left} ->
        find_contract_creation_block_number(%{block_ranges | right: middle}, address_hash, retries_left)

      :error ->
        :error
    end
  end

  # The address already has a nonce at block 0 (e.g. it is allocated in genesis), so there is no creation block
  defp find_contract_creation_block_number(%{left: 0, right: 0}, _address_hash, _retries_left), do: :not_found

  # The search has narrowed down to the max block without querying it. Without a nonce there the address was created
  # later, or it got no nonce at creation (e.g. it is allocated in genesis without a nonce, or created before EIP-161).
  defp find_contract_creation_block_number(%{right: block_number, max: block_number}, address_hash, retries_left) do
    case fetch_nonce(address_hash, block_number, retries_left) do
      {:ok, 0, _retries_left} -> :not_found
      {:ok, _nonce, _retries_left} -> block_number
      :error -> :error
    end
  end

  defp find_contract_creation_block_number(%{left: block_number}, _address_hash, _retries_left), do: block_number

  defp fetch_nonce(address_hash, block_number, retries_left) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    params = %{block_quantity: integer_to_quantity(block_number), address: to_string(address_hash)}

    case params
         |> Map.merge(%{id: 0})
         |> Nonce.request()
         |> json_rpc(json_rpc_named_arguments) do
      {:ok, response} ->
        case quantity_to_integer(response) do
          nonce when is_integer(nonce) ->
            {:ok, nonce, retries_left}

          nil ->
            Logger.error("Error while fetching 'eth_getTransactionCount' for address #{to_string(address_hash)}")
            retry_fetch_nonce(address_hash, block_number, retries_left)
        end

      {:error, reason} ->
        Logger.error(
          "Error while fetching 'eth_getTransactionCount' for address #{to_string(address_hash)}: #{inspect(reason)}"
        )

        retry_fetch_nonce(address_hash, block_number, retries_left)
    end
  end

  defp retry_fetch_nonce(address_hash, _block_number, 0) do
    Logger.error("Reached max retry attempts for 'eth_getTransactionCount' for address #{to_string(address_hash)}")

    :error
  end

  defp retry_fetch_nonce(address_hash, block_number, retries_left) do
    :timer.sleep(1000)
    fetch_nonce(address_hash, block_number, retries_left - 1)
  end

  @impl true
  def init([]) do
    schedule_sweep()

    {:ok, %{}}
  end

  @impl true
  def handle_cast({:fetch, address}, state) do
    address_hash = address.hash
    key = address_cache_name(address_hash)

    # several requests can cast a fetch for the same address before the first cast is handled
    unless fresh_entry?(key) do
      forget_pending_block(key)
      lookup_ref = make_ref()
      :ets.insert(@table_name, {key, {:in_progress, lookup_ref}, now()})

      Task.start(fn ->
        result = fetch_contract_creator_address_hash(address_hash)
        GenServer.cast(__MODULE__, {:fetch_result, address_hash, lookup_ref, result})
      end)
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:fetch_result, address_hash, lookup_ref, result}, state) do
    key = address_cache_name(address_hash)

    # the entry may have expired and been taken over by a newer lookup, its state must not be overwritten
    case :ets.lookup(@table_name, key) do
      [{^key, {:in_progress, ^lookup_ref}, _updated_at}] ->
        apply_fetch_result(address_hash, key, result)

      _ ->
        Logger.warning(
          "Dropping outdated contract creation block lookup result for address #{to_string(address_hash)}: #{inspect(result)}"
        )
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:update_pending_contract_creator_cache, imported}, state) do
    imported
    |> Map.get(:blocks, [])
    |> Enum.each(&remove_imported_block(Map.get(&1, :number)))

    {:noreply, state}
  end

  @impl true
  def handle_info(:sweep, state) do
    sweep_expired_entries()
    schedule_sweep()

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp apply_fetch_result(_address_hash, key, contract_creation_block_number)
       when is_integer(contract_creation_block_number) do
    :ets.insert(@table_name, {key, contract_creation_block_number, now()})
    add_to_block_index(contract_creation_block_number, key)

    # Change `1` to specific label when `priority` field becomes `Ecto.Enum`.
    priority = 1

    if InternalTransaction.disabled?() do
      if Block.indexed?(contract_creation_block_number) do
        # credo:disable-for-lines:2 Credo.Check.Refactor.Nesting
        if RangesHelper.traceable_block_number?(contract_creation_block_number) do
          PendingOperationsHelper.insert_pending_operations([contract_creation_block_number], priority)
        end
      else
        MissingBlockRange.add_ranges_by_block_numbers([contract_creation_block_number], priority)
      end
    else
      unless Block.indexed?(contract_creation_block_number) do
        MissingBlockRange.add_ranges_by_block_numbers([contract_creation_block_number], priority)
      end
    end
  end

  # kept until the entry expires, so that the search is not repeated on every request
  defp apply_fetch_result(_address_hash, key, :not_found) do
    :ets.insert(@table_name, {key, :not_found, now()})
  end

  defp apply_fetch_result(address_hash, key, unexpected_value) do
    Logger.error(
      "Unexpected contract creation block number for address #{to_string(address_hash)}: #{inspect(unexpected_value)}"
    )

    :ets.delete(@table_name, key)
  end

  defp address_cache_name(address_hash) do
    to_string(address_hash)
  end

  defp table_exists? do
    :ets.whereis(@table_name) != :undefined
  end

  @doc """
  Asynchronously removes the imported blocks from the pending blocks index of the
  ETS cache :contract_creator_lookup, so that their addresses are checked again on
  the next request.
  """
  @spec async_update_cache_of_contract_creator_on_demand(map()) :: :ok
  def async_update_cache_of_contract_creator_on_demand(imported) do
    GenServer.cast(__MODULE__, {:update_pending_contract_creator_cache, imported})
    :ok
  end

  defp fresh_entry?(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, _lookup_state, updated_at}] -> not expired?(updated_at)
      _ -> false
    end
  end

  defp expired?(updated_at), do: now() - updated_at > @entry_ttl

  defp now, do: System.monotonic_time(:millisecond)

  defp add_to_block_index(block_number, key) do
    index_key = {:pending_block, block_number}

    keys =
      case :ets.lookup(@table_name, index_key) do
        [{^index_key, keys}] -> List.delete(keys, key)
        [] -> []
      end

    :ets.insert(@table_name, {index_key, [key | keys]})
  end

  # An expired entry of the address may still be referenced by the index of its block
  defp forget_pending_block(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, block_number, _updated_at}] when is_integer(block_number) -> remove_from_block_index(block_number, key)
      _ -> :ok
    end
  end

  defp remove_from_block_index(block_number, key) do
    index_key = {:pending_block, block_number}

    case :ets.lookup(@table_name, index_key) do
      [{^index_key, keys}] ->
        case List.delete(keys, key) do
          [] -> :ets.delete(@table_name, index_key)
          rest -> :ets.insert(@table_name, {index_key, rest})
        end

      [] ->
        :ok
    end
  end

  # The addresses of an imported block are checked again on the next request,
  # their creator is expected to be indexed by then
  defp remove_imported_block(block_number) do
    # todo: emit event that contract creator updated for the contract. This was the purpose keeping address_hash_string in that cache key.
    case :ets.take(@table_name, {:pending_block, block_number}) do
      [{_index_key, keys}] -> Enum.each(keys, &:ets.match_delete(@table_name, {&1, block_number, :_}))
      [] -> :ok
    end
  end

  defp schedule_sweep do
    Process.send_after(self(), :sweep, @sweep_interval)
  end

  # Drops the address entries that outlived the TTL together with their block index records
  defp sweep_expired_entries do
    cutoff = now() - @entry_ttl

    @table_name
    |> :ets.select([{{:"$1", :"$2", :"$3"}, [{:<, :"$3", cutoff}], [{{:"$1", :"$2"}}]}])
    |> Enum.each(fn {key, lookup_state} ->
      if is_integer(lookup_state), do: remove_from_block_index(lookup_state, key)
      :ets.delete(@table_name, key)
    end)
  end
end
