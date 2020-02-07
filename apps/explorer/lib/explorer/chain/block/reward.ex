defmodule Explorer.Chain.Block.Reward do
  @moduledoc """
  Represents the total reward given to an address in a block.
  """

  use Explorer.Schema

  alias Explorer.Chain.Block.Reward.AddressType
  alias Explorer.Chain.{Address, Block, Hash, Wei}
  alias Explorer.{PagingOptions, Repo}

  @required_attrs ~w(address_hash address_type block_hash reward)a

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
          reward: Wei.t()
        }

  @primary_key false
  schema "block_rewards" do
    field(:address_type, AddressType)
    field(:reward, Wei)

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
    where(query, [_, block], block.number < ^block_number)
  end

  @doc """
  Returns a list of tuples representing rewards by the EmissionFunds on POA chains.
  The tuples have the format {EmissionFunds, Validator}
  """
  def fetch_emission_rewards_tuples(address_hash, paging_options, %{
        min_block_number: min_block_number,
        max_block_number: max_block_number
      }) do
    address_rewards =
      __MODULE__
      |> join_associations()
      |> paginate(paging_options)
      |> limit(^paging_options.page_size)
      |> order_by([_, block], desc: block.number)
      |> where([reward], reward.address_hash == ^address_hash)
      |> address_rewards_blocks_ranges_clause(min_block_number, max_block_number, paging_options)
      |> Repo.all()

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
          |> join_associations()
          |> order_by([_, block], desc: block.number)
          |> where([reward], reward.address_type == ^other_type)
          |> where([reward], reward.block_hash in ^block_hashes)
          |> Repo.all()

        if other_type == :emission_funds do
          Enum.zip(other_rewards, address_rewards)
        else
          Enum.zip(address_rewards, other_rewards)
        end
    end
  end

  defp join_associations(query) do
    query
    |> preload(:address)
    |> join(:inner, [reward], block in assoc(reward, :block))
    |> preload(:block)
  end

  defp address_rewards_blocks_ranges_clause(query, min_block_number, max_block_number, paging_options) do
    if is_number(min_block_number) and max_block_number > 0 and min_block_number > 0 do
      cond do
        paging_options.page_number == 1 ->
          query
          |> where([_, block], block.number >= ^min_block_number)

        min_block_number == max_block_number ->
          query
          |> where([_, block], block.number == ^min_block_number)

        true ->
          query
          |> where([_, block], block.number >= ^min_block_number)
          |> where([_, block], block.number <= ^max_block_number)
      end
    else
      query
    end
  end
end
