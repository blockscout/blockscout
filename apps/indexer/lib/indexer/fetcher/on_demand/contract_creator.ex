defmodule Indexer.Fetcher.OnDemand.ContractCreator do
  @moduledoc """
  Ensures that we have a smart-contract creator address indexed.
  """

  require Logger

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  import EthereumJSONRPC, only: [id_to_params: 1, integer_to_quantity: 1, json_rpc: 2]

  alias EthereumJSONRPC.Nonce
  alias Explorer.Chain.Address
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Utility.MissingRangesManipulator

  @table_name :contract_creator_lookup
  @pending_blocks_cache_key "pending_blocks"

  def start_link(_) do
    :ets.new(@table_name, [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec trigger_fetch(Address.t()) :: :ok | :ignore
  def trigger_fetch(address) do
    creation_transaction = Address.creation_transaction(address)
    creator_hash = creation_transaction && creation_transaction.from_address_hash

    with false <- is_nil(address.contract_code),
         true <- is_nil(creator_hash),
         {:address_lookup, [{_, contract_creation_block_number}]} <-
           {:address_lookup, :ets.lookup(@table_name, address_cache_name(address.hash))},
         {:pending_blocks_lookup, [{@pending_blocks_cache_key, blocks}]} <-
           {:pending_blocks_lookup, :ets.lookup(@table_name, @pending_blocks_cache_key)},
         contract_creation_block when is_nil(contract_creation_block) <-
           Enum.find(blocks, fn %{block_number: block_number} ->
             block_number == contract_creation_block_number
           end) do
      GenServer.cast(__MODULE__, {:fetch, address})
    else
      {:address_lookup, []} ->
        GenServer.cast(__MODULE__, {:fetch, address})

      _ ->
        :ignore
    end
  end

  @spec fetch_contract_creator_address_hash(Explorer.Chain.Hash.Address.t()) :: :ok
  defp fetch_contract_creator_address_hash(address_hash) do
    max_block_number = BlockNumber.get_max()

    initial_block_ranges = %{
      left: 0,
      right: max_block_number,
      previous_nonce: nil
    }

    contract_creation_block_number = find_contract_creation_block_number(initial_block_ranges, address_hash)

    pending_blocks =
      case pending_blocks_cache() do
        [] ->
          []

        [{_, pending_blocks}] ->
          pending_blocks
      end

    updated_pending_blocks =
      case Enum.member?(pending_blocks, contract_creation_block_number) do
        true ->
          pending_blocks

        false ->
          [
            %{block_number: contract_creation_block_number, address_hash_string: to_string(address_hash)}
            | pending_blocks
          ]
      end

    :ets.insert(@table_name, {@pending_blocks_cache_key, updated_pending_blocks})

    # Change `1` to specific label when `priority` field becomes `Ecto.Enum`.
    MissingRangesManipulator.add_ranges_by_block_numbers([contract_creation_block_number], 1)
  end

  defp find_contract_creation_block_number(block_ranges, address_hash) do
    :ets.insert(@table_name, {address_cache_name(address_hash), :in_progress})
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
    medium = trunc((block_ranges.right - block_ranges.left) / 2)
    medium_position = block_ranges.left + medium

    params = %{block_quantity: integer_to_quantity(medium_position), address: to_string(address_hash)}

    id_to_params = id_to_params([params])

    with {:ok, response} <-
           params
           |> Map.merge(%{id: 0})
           |> Nonce.request()
           |> json_rpc(json_rpc_named_arguments) do
      case Nonce.from_response(%{id: 0, result: response}, id_to_params) do
        {:ok, %{nonce: 0}} ->
          left_new = new_left_position(medium, medium_position)
          block_ranges = Map.put(block_ranges, :left, left_new)

          maybe_continue_binary_search(block_ranges, address_hash, 0)

        {:ok, %{nonce: nonce}} when nonce > 0 ->
          right_new = new_right_position(medium, medium_position)
          block_ranges = Map.put(block_ranges, :right, right_new)

          maybe_continue_binary_search(block_ranges, address_hash, nonce)

        _ ->
          Logger.error("Error while fetching 'eth_getTransactionCount' for address #{to_string(address_hash)}")
          :timer.sleep(1000)
          find_contract_creation_block_number(block_ranges, address_hash)
      end
    end
  end

  defp new_left_position(medium, medium_position) do
    if medium == 0, do: medium_position + 1, else: medium_position
  end

  defp new_right_position(medium, medium_position) do
    if medium == 0, do: medium_position - 1, else: medium_position
  end

  defp maybe_continue_binary_search(block_ranges, address_hash, nonce) do
    cond do
      block_ranges.left == block_ranges.right ->
        block_ranges.left

      block_ranges.right - block_ranges.left == 1 && nonce !== block_ranges.previous_nonce ->
        block_ranges.right

      true ->
        block_ranges = Map.put(block_ranges, :previous_nonce, nonce)
        find_contract_creation_block_number(block_ranges, address_hash)
    end
  end

  @impl true
  def init([]) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:fetch, address}, state) do
    fetch_contract_creator_address_hash(address.hash)

    {:noreply, state}
  end

  defp address_cache_name(address_hash) do
    to_string(address_hash)
  end

  @doc """
  Returns the name of the table associated with the contract creator.

  This function retrieves the value of the `@table_name` module attribute,
  which is expected to hold the name of the table used for storing or
  retrieving data related to the contract creator.
  """
  @spec table_name() :: atom()
  def table_name do
    @table_name
  end

  @doc """
  Retrieves the cached list of blocks where contract creator lookup is pending from the ETS table.

  The function looks up the ETS table using the key `"pending_blocks"` and returns
  a list of tuples where each tuple contains a string (representing the block identifier)
  and a list of maps (representing the block data).

  ## Returns

  - `[{String.t(), [map()]}]`: A list of tuples containing block identifiers and their associated data.

  """
  @spec pending_blocks_cache() :: [{String.t(), [map()]}]
  def pending_blocks_cache, do: :ets.lookup(@table_name, @pending_blocks_cache_key)

  @doc """
  Returns the cache key used for storing pending blocks.

  This function retrieves the value of the module attribute `@pending_blocks_cache_key`,
  which is used as the identifier for caching pending blocks.

  ## Examples

      iex> Indexer.Fetcher.OnDemand.ContractCreator.pending_blocks_cache_key()
      "some_cache_key"

  """
  @spec pending_blocks_cache_key() :: String.t()
  def pending_blocks_cache_key do
    @pending_blocks_cache_key
  end
end
