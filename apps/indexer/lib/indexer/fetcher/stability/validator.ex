defmodule Indexer.Fetcher.Stability.Validator do
  @moduledoc """
  GenServer responsible for updating the list of stability validators in the database.
  """
  use GenServer

  alias Explorer.Chain.Hash.Address, as: AddressHash
  alias Explorer.Chain.Stability.Validator, as: ValidatorStability

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(state) do
    GenServer.cast(__MODULE__, :update_validators_list)

    {:ok, state}
  end

  def handle_cast(:update_validators_list, state) do
    validators_from_db = ValidatorStability.get_all_validators()

    case ValidatorStability.fetch_validators_lists() do
      %{active: active_validator_addresses_list, all: validator_addresses_list} ->
        validators_map = Enum.reduce(validator_addresses_list, %{}, fn address, map -> Map.put(map, address, true) end)

        active_validators_map =
          Enum.reduce(active_validator_addresses_list, %{}, fn address, map -> Map.put(map, address, true) end)

        address_hashes_to_drop_from_db =
          Enum.flat_map(validators_from_db, fn validator ->
            (is_nil(validators_map[validator.address_hash.bytes]) && [validator.address_hash]) || []
          end)

        grouped =
          Enum.group_by(validator_addresses_list, fn validator_address -> active_validators_map[validator_address] end)

        inactive =
          Enum.map(grouped[nil] || [], fn address_hash ->
            {:ok, address_hash} = AddressHash.load(address_hash)

            %{address_hash: address_hash, state: :inactive} |> ValidatorStability.append_timestamps()
          end)

        validators_to_missing_blocks_numbers = ValidatorStability.fetch_missing_blocks_numbers(grouped[true] || [])

        active =
          Enum.map(grouped[true] || [], fn address_hash_init ->
            {:ok, address_hash} = AddressHash.load(address_hash_init)

            %{
              address_hash: address_hash,
              state:
                ValidatorStability.missing_block_number_to_state(
                  validators_to_missing_blocks_numbers[address_hash_init]
                )
            }
            |> ValidatorStability.append_timestamps()
          end)

        ValidatorStability.insert_validators(
          (active ++ inactive)
          |> add_blocks_validated(validators_from_db)
        )

        ValidatorStability.delete_validators_by_address_hashes(address_hashes_to_drop_from_db)

      _ ->
        nil
    end

    {:noreply, state}
  end

  defp add_blocks_validated([_ | _] = validators, validators_from_db) do
    validators_from_db_map =
      Enum.reduce(validators_from_db, %{}, fn validator, map -> Map.put(map, validator.address_hash, true) end)

    address_hashes_to_fetch_blocks_validated =
      Enum.flat_map(validators, fn validator ->
        if validators_from_db_map[validator.address_hash] do
          []
        else
          [validator.address_hash]
        end
      end)

    blocks_validated_map =
      address_hashes_to_fetch_blocks_validated
      |> ValidatorStability.fetch_blocks_validated()
      |> Enum.into(%{})

    Enum.map(validators, fn validator ->
      Map.put(validator, :blocks_validated, blocks_validated_map[validator.address_hash] || 0)
    end)
  end

  defp add_blocks_validated(validators, _), do: validators

  @spec trigger_update_validators_list() :: :ok
  def trigger_update_validators_list do
    GenServer.cast(__MODULE__, :update_validators_list)
  end
end
