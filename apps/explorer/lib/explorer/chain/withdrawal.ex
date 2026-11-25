# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Withdrawal do
  @moduledoc """
  A stored representation of withdrawal introduced in [EIP-4895](https://eips.ethereum.org/EIPS/eip-4895)
  """

  use Explorer.Schema
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias Explorer.Chain.{Address, Block, Hash, Wei}
  alias Explorer.Chain.Cache.Counters
  alias Explorer.Chain.Cache.Counters.WithdrawalsSum
  alias Explorer.PagingOptions

  # On Bera chain type every block starts with a synthetic "EVM inflation"
  # withdrawal minting the block reward. Its `index` and `validator_index` are
  # always equal to the max `uint64` value, so:
  #
  #   * the indexes are stored as decimals, since the max `uint64` value does
  #     not fit into `bigint`;
  #   * `index` is not unique, so withdrawals are identified by
  #     `(block_number, index)` and ordered by the same pair.
  @bera? @chain_type == :bera

  @required_attrs (if @bera? do
                     ~w(index validator_index amount address_hash block_hash block_number)a
                   else
                     ~w(index validator_index amount address_hash block_hash)a
                   end)

  @primary_key false
  if @bera? do
    typed_schema "withdrawals" do
      field(:index, :decimal, primary_key: true, null: false)
      field(:validator_index, :decimal, null: false)
      field(:block_number, :integer, primary_key: true, null: false)
      field(:amount, Wei, null: false)

      belongs_to(:address, Address,
        foreign_key: :address_hash,
        references: :hash,
        type: Hash.Address,
        null: false
      )

      belongs_to(:block, Block,
        foreign_key: :block_hash,
        references: :hash,
        type: Hash.Full,
        null: false
      )

      timestamps()
    end
  else
    typed_schema "withdrawals" do
      field(:index, :integer, primary_key: true, null: false)
      field(:validator_index, :integer, null: false)
      field(:amount, Wei, null: false)

      belongs_to(:address, Address,
        foreign_key: :address_hash,
        references: :hash,
        type: Hash.Address,
        null: false
      )

      belongs_to(:block, Block,
        foreign_key: :block_hash,
        references: :hash,
        type: Hash.Full,
        null: false
      )

      timestamps()
    end
  end

  @spec changeset(
          Explorer.Chain.Withdrawal.t(),
          :invalid | %{optional(:__struct__) => none, optional(atom | binary) => any}
        ) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = withdrawal, attrs \\ %{}) do
    withdrawal
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:index, name: :withdrawals_pkey)
  end

  @spec page_withdrawals(Ecto.Query.t(), PagingOptions.t()) :: Ecto.Query.t()
  def page_withdrawals(query, %PagingOptions{key: nil}), do: query

  if @bera? do
    def page_withdrawals(query, %PagingOptions{key: {block_number, index}}) do
      where(
        query,
        [withdrawal],
        withdrawal.block_number < ^block_number or
          (withdrawal.block_number == ^block_number and withdrawal.index < ^index)
      )
    end
  else
    def page_withdrawals(query, %PagingOptions{key: {index}}) do
      where(query, [withdrawal], withdrawal.index < ^index)
    end
  end

  # The order in which the withdrawals are listed and paginated.
  @spec order_by_default(Ecto.Query.t()) :: Ecto.Query.t()
  if @bera? do
    defp order_by_default(query),
      do: order_by(query, [withdrawal], desc: withdrawal.block_number, desc: withdrawal.index)
  else
    defp order_by_default(query), do: order_by(query, [withdrawal], desc: withdrawal.index)
  end

  @spec block_hash_to_withdrawals_query(Hash.Full.t()) :: Ecto.Query.t()
  def block_hash_to_withdrawals_query(block_hash) do
    block_hash
    |> block_hash_to_withdrawals_unordered_query()
    |> order_by_default()
  end

  @spec block_hash_to_withdrawals_unordered_query(Hash.Full.t()) :: Ecto.Query.t()
  def block_hash_to_withdrawals_unordered_query(block_hash) do
    from(withdrawal in __MODULE__,
      select: withdrawal,
      where: withdrawal.block_hash == ^block_hash
    )
  end

  @spec address_hash_to_withdrawals_query(Hash.Address.t()) :: Ecto.Query.t()
  def address_hash_to_withdrawals_query(address_hash) do
    address_hash
    |> address_hash_to_withdrawals_unordered_query()
    |> order_by_default()
  end

  @spec address_hash_to_withdrawals_unordered_query(Hash.Address.t()) :: Ecto.Query.t()
  def address_hash_to_withdrawals_unordered_query(address_hash) do
    from(withdrawal in __MODULE__,
      select: withdrawal,
      left_join: block in assoc(withdrawal, :block),
      where: withdrawal.address_hash == ^address_hash,
      where: block.consensus == true,
      preload: [block: block]
    )
  end

  @spec address_hash_to_withdrawals_existence_query(Hash.Address.t()) :: Ecto.Query.t()
  def address_hash_to_withdrawals_existence_query(address_hash) do
    from(withdrawal in __MODULE__,
      left_join: block in assoc(withdrawal, :block),
      where: withdrawal.address_hash == ^address_hash,
      where: block.consensus == true,
      select: 1
    )
  end

  @spec blocks_without_withdrawals_query(non_neg_integer()) :: Ecto.Query.t()
  def blocks_without_withdrawals_query(from_block) do
    from(withdrawal in __MODULE__,
      right_join: block in assoc(withdrawal, :block),
      select: block.number,
      distinct: block.number,
      where: block.number >= ^from_block,
      where: block.consensus == ^true,
      where: is_nil(withdrawal.index)
    )
  end

  @spec list_withdrawals :: Ecto.Query.t()
  if @bera? do
    # Unlike other chain types, a withdrawal of a block that lost consensus is
    # not necessarily overwritten by the withdrawal with the same index from
    # the new consensus block, so such withdrawals are filtered out explicitly.
    def list_withdrawals do
      from(withdrawal in __MODULE__,
        as: :withdrawal,
        select: withdrawal,
        where:
          exists(
            from(block in Block,
              where: block.hash == parent_as(:withdrawal).block_hash and block.consensus == true,
              select: 1
            )
          )
      )
      |> order_by_default()
    end
  else
    def list_withdrawals do
      from(withdrawal in __MODULE__,
        select: withdrawal
      )
      |> order_by_default()
    end
  end

  @doc """
  Upserts the count of all withdrawals into the `last_fetched_counters` table.

  The count is derived from the index of the latest withdrawal. This is not
  applicable to Bera chain type, where the index is not unique, so the function
  does nothing there (see `count_withdrawals_from_cache/1`).
  """
  @spec upsert_count_withdrawals(non_neg_integer() | Decimal.t()) :: {:ok, any()} | {:error, any()} | nil
  if @bera? do
    def upsert_count_withdrawals(_index), do: nil
  else
    def upsert_count_withdrawals(index) do
      current_value = Counters.LastFetchedCounter.get("withdrawals_count")

      if index > current_value do
        Counters.LastFetchedCounter.upsert(%{
          counter_type: "withdrawals_count",
          value: index
        })
      end
    end
  end

  @doc """
  Fetches the count of withdrawals.

  The count is the cached index of the latest withdrawal plus 1. On Bera chain
  type, where the index is not unique, it is the estimated number of rows in
  the `withdrawals` table instead.
  """
  @spec count_withdrawals_from_cache(Keyword.t()) :: Decimal.t()
  if @bera? do
    def count_withdrawals_from_cache(options \\ []) do
      Decimal.new(Counters.Helper.estimated_count_from("withdrawals", options) || 0)
    end
  else
    def count_withdrawals_from_cache(options \\ []) do
      "withdrawals_count" |> Counters.LastFetchedCounter.get(options) |> Decimal.add(1)
    end
  end

  @doc """
  Fetches the sum of withdrawals from the cache.
  """
  @spec sum_withdrawals_from_cache(Keyword.t()) :: Decimal.t() | nil
  def sum_withdrawals_from_cache(options \\ []) do
    WithdrawalsSum.fetch(options)
  end
end
