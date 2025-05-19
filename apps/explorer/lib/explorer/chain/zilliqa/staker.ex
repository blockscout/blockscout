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
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Zilliqa.Hash.PeerID

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
  """
  @primary_key false
  typed_schema "zilliqa_stakers" do
    field(:bls_public_key, :string,
      source: :id,
      primary_key: true
    )

    field(:index, :integer)
    field(:balance, :decimal, null: false)
    field(:peer_id, PeerID)

    belongs_to(:control_address, Address,
      foreign_key: :control_address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(:reward_address, Address,
      foreign_key: :reward_address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(:signing_address, Address,
      foreign_key: :signing_address_hash,
      references: :hash,
      type: Hash.Address
    )

    field(:added_at_block_number, :integer, null: false)
    field(:stake_updated_at_block_number, :integer, null: false)
    timestamps()
  end

  @doc """
  Query returning stakers that are currently present in the committee.
  """
  @spec active_stakers_query() :: Ecto.Query.t()
  def active_stakers_query do
    max_block_number = BlockNumber.get_max()

    from(s in __MODULE__,
      where:
        s.balance > 0 and
          s.added_at_block_number <= ^max_block_number
    )
  end

  @doc """
  Get staker by BLS public key.
  """
  @spec bls_public_key_to_staker(binary(), keyword()) :: {:ok, t()} | {:error, :not_found}
  def bls_public_key_to_staker(bls_public_key, options \\ []) do
    staker = Chain.select_repo(options).get(__MODULE__, bls_public_key)

    case staker do
      nil -> {:error, :not_found}
      staker -> {:ok, staker}
    end
  end

  @doc """
  Get paginated list of active stakers.
  """
  @spec paginated_active_stakers(keyword()) :: [t()]
  def paginated_active_stakers(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    sorting = Keyword.get(options, :sorting, [])

    active_stakers_query()
    |> Chain.join_associations(necessity_by_association)
    |> SortingHelper.apply_sorting(sorting, @default_sorting)
    |> SortingHelper.page_with_sorting(paging_options, sorting, @default_sorting)
    |> Chain.select_repo(options).all()
  end

  @doc """
  Derive next page params
  """
  @spec next_page_params(t()) :: map()
  def next_page_params(%__MODULE__{index: index}) do
    %{"index" => index}
  end
end
