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
         true <- is_nil(creator_hash) do
      case :ets.lookup(@table_name, address_cache_name(address.hash)) do
        [{_, :in_progress}] ->
          :ignore

        [] ->
          GenServer.cast(__MODULE__, {:fetch, address})

        [{_, contract_creation_block_number}] ->
          case :ets.lookup(@table_name, "pending_blocks") do
            [] ->
              :ignore

            [{"pending_blocks", blocks}] ->
              contract_creation_block =
                Enum.find(blocks, fn %{block_number: block_number, address_hash_string: _address_hash_string} ->
                  block_number == contract_creation_block_number
                end)

              # credo:disable-for-next-line
              if is_nil(contract_creation_block), do: GenServer.cast(__MODULE__, {:fetch, address}), else: :ignore
          end
      end
    else
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
      case :ets.lookup(@table_name, "pending_blocks") do
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

    :ets.insert(@table_name, {"pending_blocks", updated_pending_blocks})

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
end
