defmodule Explorer.Chain.Stability.Validator do
  @moduledoc """
    Stability validators
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Block, Import}
  alias Explorer.Chain.Hash.Address, as: HashAddress
  alias Explorer.{Chain, Repo, SortingHelper}
  alias Explorer.SmartContract.Reader

  require Logger

  @default_sorting [
    asc: :state,
    asc: :address_hash
  ]

  @state_enum [active: 0, probation: 1, inactive: 2]

  @primary_key false
  typed_schema "validators_stability" do
    field(:address_hash, HashAddress, primary_key: true)
    field(:state, Ecto.Enum, values: @state_enum)
    field(:blocks_validated, :integer)

    has_one(:address, Address, foreign_key: :hash, references: :address_hash)
    timestamps()
  end

  @required_attrs ~w(address_hash blocks_validated)a
  @optional_attrs ~w(state)a
  def changeset(%__MODULE__{} = validator, attrs) do
    validator
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:address_hash)
  end

  @doc """
    Get validators list.
    Keyword could contain:
      - paging_options
      - necessity_by_association
      - sorting (supported by `Explorer.SortingHelper` module)
      - state (one of `@state_enum`)
  """
  @spec get_paginated_validators(keyword()) :: [t()]
  def get_paginated_validators(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    sorting = Keyword.get(options, :sorting, [])
    states = Keyword.get(options, :state, [])

    __MODULE__
    |> apply_filter_by_state(states)
    |> Chain.join_associations(necessity_by_association)
    |> SortingHelper.apply_sorting(sorting, @default_sorting)
    |> SortingHelper.page_with_sorting(paging_options, sorting, @default_sorting)
    |> Chain.select_repo(options).all()
  end

  defp apply_filter_by_state(query, []), do: query

  defp apply_filter_by_state(query, states) do
    query
    |> where([vs], vs.state in ^states)
  end

  @doc """
    Get all validators
  """
  @spec get_all_validators(keyword()) :: [t()]
  def get_all_validators(options \\ []) do
    __MODULE__
    |> Chain.select_repo(options).all()
  end

  @get_active_validator_list_abi %{
    "type" => "function",
    "stateMutability" => "view",
    "payable" => false,
    "outputs" => [%{"type" => "address[]", "name" => "", "internalType" => "address[]"}],
    "name" => "getActiveValidatorList",
    "inputs" => []
  }

  @get_validator_list_abi %{
    "type" => "function",
    "stateMutability" => "view",
    "payable" => false,
    "outputs" => [%{"type" => "address[]", "name" => "", "internalType" => "address[]"}],
    "name" => "getValidatorList",
    "inputs" => []
  }

  @get_validator_missing_blocks_abi %{
    "inputs" => [
      %{
        "internalType" => "address",
        "name" => "validator",
        "type" => "address"
      }
    ],
    "name" => "getValidatorMissingBlocks",
    "outputs" => [
      %{
        "internalType" => "uint256",
        "name" => "",
        "type" => "uint256"
      }
    ],
    "stateMutability" => "view",
    "type" => "function"
  }

  @get_active_validator_list_method_id "a5aa7380"
  @get_validator_list_method_id "e35c0f7d"
  @get_validator_missing_blocks_method_id "41ee9a53"

  @stability_validator_controller_contract "0x0000000000000000000000000000000000000805"

  @doc """
    Do batch eth_call of `getValidatorList` and `getActiveValidatorList` methods to `@stability_validator_controller_contract`.
    Returns a map with two lists: `active` and `all`, or nil if error.
  """
  @spec fetch_validators_lists :: nil | %{active: list(binary()), all: list(binary())}
  def fetch_validators_lists do
    abi = [@get_active_validator_list_abi, @get_validator_list_abi]
    params = %{@get_validator_list_method_id => [], @get_active_validator_list_method_id => []}

    case Reader.query_contract(@stability_validator_controller_contract, abi, params, false) do
      %{
        @get_active_validator_list_method_id => {:ok, [active_validators_list]},
        @get_validator_list_method_id => {:ok, [validators_list]}
      } ->
        %{active: active_validators_list, all: validators_list}

      error ->
        Logger.warning(fn -> ["Error on getting validator lists: #{inspect(error)}"] end)
        nil
    end
  end

  @doc """
    Do batch eth_call of `getValidatorMissingBlocks` method to #{@stability_validator_controller_contract}.
    Accept: list of validator address hashes
    Returns a map: validator_address_hash => missing_blocks_number
  """
  @spec fetch_missing_blocks_numbers(list(binary())) :: map()
  def fetch_missing_blocks_numbers(validators_address_hashes) do
    validators_address_hashes
    |> Enum.map(&format_request_missing_blocks_number/1)
    |> Reader.query_contracts([@get_validator_missing_blocks_abi])
    |> Enum.zip_reduce(validators_address_hashes, %{}, fn response, address_hash, acc ->
      result =
        case format_missing_blocks_result(response) do
          {:error, message} ->
            Logger.warning(fn -> ["Error on getValidatorMissingBlocks for #{validators_address_hashes}: #{message}"] end)

            nil

          amount ->
            amount
        end

      Map.put(acc, address_hash, result)
    end)
  end

  defp format_missing_blocks_result({:ok, [amount]}) do
    amount
  end

  defp format_missing_blocks_result({:error, error_message}) do
    {:error, error_message}
  end

  defp format_request_missing_blocks_number(address_hash) do
    %{
      contract_address: @stability_validator_controller_contract,
      method_id: @get_validator_missing_blocks_method_id,
      args: [address_hash]
    }
  end

  @doc """
    Convert missing block number to state
  """
  @spec missing_block_number_to_state(integer()) :: atom()
  def missing_block_number_to_state(integer) when integer > 0, do: :probation
  def missing_block_number_to_state(integer) when integer == 0, do: :active
  def missing_block_number_to_state(_), do: nil

  @doc """
    Delete validators by address hashes
  """
  @spec delete_validators_by_address_hashes([binary() | HashAddress.t()]) :: {non_neg_integer(), nil | []} | :ignore
  def delete_validators_by_address_hashes(list) when is_list(list) and length(list) > 0 do
    __MODULE__
    |> where([vs], vs.address_hash in ^list)
    |> Repo.delete_all()
  end

  def delete_validators_by_address_hashes(_), do: :ignore

  @doc """
    Insert validators
  """
  @spec insert_validators([map()]) :: {non_neg_integer(), nil | []}
  def insert_validators(validators) do
    Repo.insert_all(__MODULE__, validators,
      on_conflict: {:replace_all_except, [:inserted_at, :blocks_validated]},
      conflict_target: [:address_hash]
    )
  end

  @doc """
    Append timestamps (:inserted_at, :updated_at)
  """
  @spec append_timestamps(map()) :: map()
  def append_timestamps(validator) do
    Map.merge(validator, Import.timestamps())
  end

  @doc """
    Derive next page params from %Explorer.Chain.Stability.Validator{}
  """
  @spec next_page_params(t()) :: map()
  def next_page_params(%__MODULE__{state: state, address_hash: address_hash, blocks_validated: blocks_validated}) do
    %{"state" => state, "address_hash" => address_hash, "blocks_validated" => blocks_validated}
  end

  @doc """
    Returns state enum
  """
  @spec state_enum() :: Keyword.t()
  def state_enum, do: @state_enum

  @doc """
    Returns total count of validators.
  """
  @spec count_validators() :: integer()
  def count_validators do
    Repo.aggregate(__MODULE__, :count, :address_hash)
  end

  @doc """
    Returns count of new validators (inserted withing last 24h).
  """
  @spec count_new_validators() :: integer()
  def count_new_validators do
    __MODULE__
    |> where([vs], vs.inserted_at >= ago(1, "day"))
    |> Repo.aggregate(:count, :address_hash)
  end

  @doc """
    Returns count of active validators.
  """
  @spec count_active_validators() :: integer()
  def count_active_validators do
    __MODULE__
    |> where([vs], vs.state == :active)
    |> Repo.aggregate(:count, :address_hash)
  end

  @doc """
    Fetch blocks validated
  """
  @spec fetch_blocks_validated(list(binary())) :: list({binary(), integer()})
  def fetch_blocks_validated([_ | _] = miner_address_hashes) do
    Block
    |> where([b], b.miner_hash in ^miner_address_hashes)
    |> group_by([b], b.miner_hash)
    |> select([b], {b.miner_hash, count(b.hash)})
    |> Repo.all()
  end

  def fetch_blocks_validated(_), do: []
end
