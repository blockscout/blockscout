defmodule Indexer.Fetcher.OnDemand.ContractCreator do
  @moduledoc """
  Ensures that we have a smart-contract creator address indexed.
  """

  require Logger

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  import EthereumJSONRPC, only: [integer_to_quantity: 1, json_rpc: 2]

  alias EthereumJSONRPC.Nonce
  alias Explorer.Chain.Address
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Utility.MissingRangesManipulator

  @table_name :contract_creator_finding

  def start_link([init_opts, server_opts]) do
    :ets.new(@table_name, [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @spec trigger_fetch(Address.t()) :: :ok
  def trigger_fetch(address) do
    creation_transaction = Address.creation_transaction(address)
    creator_hash = creation_transaction && creation_transaction.from_address_hash

    with false <- is_nil(address.contract_code),
         true <- is_nil(creator_hash) do
      case :ets.lookup(@table_name, address_cache_name(address.hash)) do
        [{_, :in_progress}] ->
          :ok

        [] ->
          GenServer.cast(__MODULE__, {:fetch, address})

        [{_, contract_creation_block_number}] ->
          case :ets.lookup(@table_name, "pending_blocks") do
            [] ->
              :ok

            [{"pending_blocks", blocks}] ->
              contract_creation_block =
                Enum.find(blocks, fn %{block_number: block_number, address_hash_string: _address_hash_string} ->
                  block_number == contract_creation_block_number
                end)

              # credo:disable-for-next-line
              if is_nil(contract_creation_block), do: GenServer.cast(__MODULE__, {:fetch, address}), else: :ok
          end
      end
    end
  end

  @spec fetch_contract_creator_address_hash(Explorer.Chain.Hash.Address.t(), %{
          json_rpc_named_arguments: EthereumJSONRPC.json_rpc_named_arguments()
        }) :: :ok
  defp fetch_contract_creator_address_hash(address_hash, %{json_rpc_named_arguments: _}) do
    max_block_number = BlockNumber.get_max()

    initial_block_ranges = %{
      left: 0,
      right: max_block_number
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

    case %{id: 0, block_quantity: integer_to_quantity(medium_position), address: to_string(address_hash)}
         |> Nonce.request()
         |> json_rpc(json_rpc_named_arguments) do
      {:ok, nonce_hex} ->
        "0x" <> hexadecimal_digits = nonce_hex
        nonce = String.to_integer(hexadecimal_digits, 16)

        case nonce do
          0 ->
            left_new = new_left_position(medium, medium_position)
            block_ranges = Map.put(block_ranges, :left, left_new)

            should_continue_binary_search?(block_ranges, address_hash)

          nonce when nonce > 0 ->
            right_new = new_right_position(medium, medium_position)
            block_ranges = Map.put(block_ranges, :right, right_new)

            should_continue_binary_search?(block_ranges, address_hash)
        end

      _ ->
        find_contract_creation_block_number(block_ranges, address_hash)
    end
  end

  defp new_left_position(medium, medium_position) do
    if medium == 0, do: medium_position + 1, else: medium_position
  end

  defp new_right_position(medium, medium_position) do
    if medium == 0, do: medium_position - 1, else: medium_position
  end

  defp should_continue_binary_search?(block_ranges, address_hash) do
    if block_ranges.left == block_ranges.right do
      block_ranges.left
    else
      find_contract_creation_block_number(block_ranges, address_hash)
    end
  end

  @impl true
  def init(json_rpc_named_arguments) do
    {:ok, %{json_rpc_named_arguments: json_rpc_named_arguments}}
  end

  @impl true
  def handle_cast({:fetch, address}, state) do
    fetch_contract_creator_address_hash(address.hash, state)

    {:noreply, state}
  end

  defp address_cache_name(address_hash) do
    to_string(address_hash)
  end

  @spec table_name() :: atom()
  @doc """
  Returns the name of the table associated with the contract creator.

  This function retrieves the value of the `@table_name` module attribute,
  which is expected to hold the name of the table used for storing or
  retrieving data related to the contract creator.
  """
  def table_name do
    @table_name
  end
end
