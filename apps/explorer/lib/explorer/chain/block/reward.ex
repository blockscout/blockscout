defmodule Explorer.Chain.Block.Reward do
  @moduledoc """
  Represents the total reward given to an address in a block.
  """

  use Explorer.Schema

  alias Explorer.Application.Constants
  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.Block.Reward.AddressType
  alias Explorer.Chain.{Address, Block, Hash, Validator, Wei}
  alias Explorer.Chain.Fetcher.FetchValidatorInfoOnDemand
  alias Explorer.SmartContract.Reader

  @required_attrs ~w(address_hash address_type block_hash block_number reward)a

  @get_payout_by_mining_abi %{
    "type" => "function",
    "stateMutability" => "view",
    "payable" => false,
    "outputs" => [%{"type" => "address", "name" => ""}],
    "name" => "getPayoutByMining",
    "inputs" => [%{"type" => "address", "name" => ""}],
    "constant" => true
  }

  @is_validator_abi %{
    "type" => "function",
    "stateMutability" => "view",
    "payable" => false,
    "outputs" => [%{"type" => "bool", "name" => ""}],
    "name" => "isValidator",
    "inputs" => [%{"type" => "address", "name" => ""}],
    "constant" => true
  }

  @empty_address "0x0000000000000000000000000000000000000000"

  @typedoc """
  The validation reward given related to a block.

  * `:address_hash` - Hash of address who received the reward
  * `:address_type` - Type of the address_hash, either emission_funds, uncle or validator
  * `:block_hash` - Hash of the validated block
  * `:reward` - Total block reward
  """
  @type t :: %__MODULE__{
          address: %Ecto.Association.NotLoaded{} | Address.t() | nil,
          address_hash: Hash.Address.t(),
          address_type: AddressType.t(),
          block: %Ecto.Association.NotLoaded{} | Block.t() | nil,
          block_hash: Hash.Full.t(),
          block_number: non_neg_integer(),
          reward: Wei.t()
        }

  @primary_key false
  schema "block_rewards" do
    field(:address_type, AddressType)
    field(:reward, Wei)
    field(:block_number, :integer)

    belongs_to(
      :address,
      Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(
      :block,
      Block,
      foreign_key: :block_hash,
      references: :hash,
      type: Hash.Full
    )

    timestamps()
  end

  def changeset(%__MODULE__{} = reward, attrs) do
    reward
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end

  def paginate(query, %PagingOptions{key: nil}), do: query

  def paginate(query, %PagingOptions{key: {block_number, _}}) do
    where(query, [reward], reward.block_number < ^block_number)
  end

  @doc """
  Returns a list of tuples representing rewards by the EmissionFunds on POA chains.
  The tuples have the format {EmissionFunds, Validator}
  """
  def fetch_emission_rewards_tuples(
        address_hash,
        paging_options,
        %{
          min_block_number: min_block_number,
          max_block_number: max_block_number
        },
        options
      ) do
    address_rewards =
      __MODULE__
      |> preload(:address)
      |> paginate(paging_options)
      |> limit(^paging_options.page_size)
      |> order_by([reward], desc: reward.block_number)
      |> where([reward], reward.address_hash == ^address_hash)
      |> address_rewards_blocks_ranges_clause(min_block_number, max_block_number, paging_options)
      |> Chain.select_repo(options).all()

    case List.first(address_rewards) do
      nil ->
        []

      reward ->
        block_hashes = Enum.map(address_rewards, & &1.block_hash)

        other_type =
          case reward.address_type do
            :validator ->
              :emission_funds

            :emission_funds ->
              :validator
          end

        other_rewards =
          __MODULE__
          |> preload(:address)
          |> order_by([reward], desc: reward.block_number)
          |> where([reward], reward.address_type == ^other_type)
          |> where([reward], reward.block_hash in ^block_hashes)
          |> Chain.select_repo(options).all()

        if other_type == :emission_funds do
          Enum.zip(other_rewards, address_rewards)
        else
          Enum.zip(address_rewards, other_rewards)
        end
    end
  end

  defp is_validator(mining_key) do
    validators_contract_address =
      Application.get_env(:explorer, Explorer.Chain.Block.Reward, %{})[:validators_contract_address]

    if validators_contract_address do
      # facd743b=keccak256(isValidator(address))
      is_validator_params = %{"facd743b" => [mining_key.bytes]}

      call_contract(validators_contract_address, @is_validator_abi, is_validator_params)
    else
      nil
    end
  end

  def get_validator_payout_key_by_mining_from_db(mining_key, options \\ []) do
    contract_address_from_db = Constants.get_keys_manager_contract_address(options)

    contract_address_from_env =
      Application.get_env(:explorer, Explorer.Chain.Block.Reward, %{})[:keys_manager_contract_address]

    cond do
      is_nil(contract_address_from_env) ->
        %{is_validator: nil, payout_key: mining_key}

      is_nil(contract_address_from_db) ->
        FetchValidatorInfoOnDemand.trigger_fetch(mining_key)
        %{is_validator: nil, payout_key: mining_key}

      contract_address_from_db.value |> String.downcase() == contract_address_from_env |> String.downcase() ->
        FetchValidatorInfoOnDemand.trigger_fetch(mining_key)
        validator = Validator.get_validator_by_address_hash(mining_key, options)
        is_validator = validator && validator.is_validator

        with {:is_validator, true} <- {:is_validator, is_validator},
             false <- is_nil(validator.payout_key_hash) do
          %{is_validator: is_validator, payout_key: validator.payout_key_hash}
        else
          _ ->
            %{is_validator: is_validator, payout_key: mining_key}
        end

      true ->
        FetchValidatorInfoOnDemand.trigger_fetch(mining_key)
        %{is_validator: nil, payout_key: mining_key}
    end
  end

  def get_validator_payout_key_by_mining(mining_key) do
    is_validator = is_validator(mining_key)

    if is_validator do
      keys_manager_contract_address =
        Application.get_env(:explorer, Explorer.Chain.Block.Reward, %{})[:keys_manager_contract_address]

      if keys_manager_contract_address do
        payout_key =
          if keys_manager_contract_address do
            # 7cded930=keccak256(getPayoutByMining(address))
            get_payout_by_mining_params = %{"7cded930" => [mining_key.bytes]}

            payout_key_hash =
              call_contract(keys_manager_contract_address, @get_payout_by_mining_abi, get_payout_by_mining_params)

            if payout_key_hash == @empty_address do
              mining_key
            else
              case Chain.string_to_address_hash(payout_key_hash) do
                {:ok, payout_key} ->
                  payout_key

                _ ->
                  mining_key
              end
            end
          else
            mining_key
          end

        %{is_validator: is_validator, payout_key: payout_key}
      else
        %{is_validator: is_validator, payout_key: mining_key}
      end
    else
      %{is_validator: is_validator, payout_key: mining_key}
    end
  end

  defp call_contract(address, abi, params) do
    abi = [abi]

    method_id =
      params
      |> Enum.map(fn {key, _value} -> key end)
      |> List.first()

    case Reader.query_contract(address, abi, params, false) do
      %{^method_id => {:ok, [result]}} -> result
      _ -> @empty_address
    end
  end

  defp address_rewards_blocks_ranges_clause(query, min_block_number, max_block_number, paging_options) do
    if is_number(min_block_number) and max_block_number > 0 and min_block_number > 0 do
      cond do
        paging_options.page_number == 1 ->
          query
          |> where([reward], reward.block_number >= ^min_block_number)

        min_block_number == max_block_number ->
          query
          |> where([reward], reward.block_number == ^min_block_number)

        true ->
          query
          |> where([reward], reward.block_number >= ^min_block_number)
          |> where([reward], reward.block_number <= ^max_block_number)
      end
    else
      query
    end
  end
end
