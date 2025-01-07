defmodule Explorer.Chain.Zilliqa.Staker do
  @moduledoc """
  Represents Zilliqa staker (i.e. validator) in the database. This is the
  equivalent to on-chain Staker entity from
  [Deposit](https://github.com/Zilliqa/zq2/blob/main/zilliqa/src/contracts/deposit_v3.sol)
  contract.
  """

  use Explorer.Schema
  alias Explorer.{Chain, SortingHelper}
  alias Explorer.Chain.{Address, Hash}

  @default_sorting [
    asc: :index
  ]

  @typedoc """
  * `bls_public_key` - BLS public key of the staker.
  * `index` - Index of the staker in the committee.
  * `balance` - Staker's balance.
  * `peer_id` - libp2p peer ID, corresponding to the staker's `blsPubKey`.
  * `control_address` - The address used for authenticating requests from this
    staker to the deposit contract.
  * `reward_address` - The address which rewards for this staker will be sent
    to.
  * `signing_address` - The address whose key with which validators sign
    cross-chain events.
  * `added_at_block_number` - Block number at which the staker was added.
  * `stake_updated_at_block_number` - Block number at which the staker's stake
    was last updated.
  * `is_removed` - Whether the staker has been removed from the committee.
  """
  @primary_key false
  typed_schema "zilliqa_stakers" do
    field(:bls_public_key, :string,
      source: :id,
      primary_key: true
    )

    field(:index, :integer)
    field(:balance, :decimal)
    field(:peer_id, :binary)

    belongs_to(:control_address, Address,
      foreign_key: :control_address_hash,
      references: :hash,
      type: Hash.Address,
      null: false
    )

    belongs_to(:reward_address, Address,
      foreign_key: :reward_address_hash,
      references: :hash,
      type: Hash.Address,
      null: false
    )

    belongs_to(:signing_address, Address,
      foreign_key: :signing_address_hash,
      references: :hash,
      type: Hash.Address,
      null: false
    )

    field(:added_at_block_number, :integer)
    field(:stake_updated_at_block_number, :integer)
    field(:is_removed, :boolean)
    timestamps()
  end

  @doc """
  Query returning stakers that are active (i.e not removed).
  """
  @spec active_stakers_query() :: Ecto.Query.t()
  def active_stakers_query do
    from(s in __MODULE__,
      where: is_nil(s.is_removed) or s.is_removed == false
    )
  end

  @doc """
  Get paginated list of active stakers.
  """
  @spec paginated_active_stakers(keyword()) :: [t()]
  def paginated_active_stakers(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    sorting = Keyword.get(options, :sorting, [])

    __MODULE__
    |> Chain.join_associations(necessity_by_association)
    |> SortingHelper.apply_sorting(sorting, @default_sorting)
    |> SortingHelper.page_with_sorting(paging_options, sorting, @default_sorting)
    |> Chain.select_repo(options).all()
  end

  @spec stakers_at_block_number_query(integer()) :: Ecto.Query.t()
  def stakers_at_block_number_query(block_number) do
    from(
      s in __MODULE__,
      where: s.added_at_block_number <= ^block_number,
      where:
        is_nil(s.removed_at_block_numbers) or
          s.removed_at_block_number > ^block_number
    )
  end

  @doc """
  Derive next page params
  """
  @spec next_page_params(t()) :: map()
  def next_page_params(%__MODULE__{index: index}) do
    %{"index" => index}
  end
end
