defmodule Indexer.Fetcher.Blackfort.Validator do
  @moduledoc """
  GenServer responsible for updating the list of blackfort validators in the database.
  """
  use GenServer

  alias Explorer.Chain.Blackfort.Validator

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(state) do
    GenServer.cast(__MODULE__, :update_validators_list)

    {:ok, state}
  end

  @impl true
  def handle_cast(:update_validators_list, state) do
    case Validator.fetch_validators_list() do
      {:ok, validators} ->
        validators_from_db = Validator.get_all_validators()

        validators_map =
          Enum.reduce(validators, %{}, fn %{address_hash: address_hash}, map ->
            Map.put(map, address_hash.bytes, true)
          end)

        address_hashes_to_drop_from_db =
          Enum.flat_map(validators_from_db, fn validator ->
            (is_nil(validators_map[validator.address_hash.bytes]) &&
               [validator.address_hash]) || []
          end)

        Validator.delete_validators_by_address_hashes(address_hashes_to_drop_from_db)

        validators
        |> Enum.map(&Validator.append_timestamps/1)
        |> Validator.insert_validators()

      _ ->
        nil
    end

    {:noreply, state}
  end

  @spec trigger_update_validators_list() :: :ok
  def trigger_update_validators_list do
    GenServer.cast(__MODULE__, :update_validators_list)
  end
end
