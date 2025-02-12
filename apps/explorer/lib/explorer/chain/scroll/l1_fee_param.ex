defmodule Explorer.Chain.Scroll.L1FeeParam do
  @moduledoc """
    Models an L1 fee parameter for Scroll.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Scroll.L1FeeParams

    Migrations:
    - Explorer.Repo.Scroll.Migrations.AddFeeFields
  """

  use Explorer.Schema

  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.Transaction

  @counter_type "scroll_l1_fee_params_fetcher_last_block_number"
  @required_attrs ~w(block_number transaction_index name value)a

  @typedoc """
    Descriptor of the L1 Fee Parameter change:
    * `block_number` - A block number of the transaction where the given parameter value was changed.
    * `transaction_index` - An index of the transaction (within the block) where the given parameter value was changed.
    * `name` - A name of the parameter (can be one of: `overhead`, `scalar`, `commit_scalar`, `blob_scalar`, `l1_base_fee`, `l1_blob_base_fee`).
    * `value` - A new value of the parameter.
  """
  @type to_import :: %{
          block_number: non_neg_integer(),
          transaction_index: non_neg_integer(),
          name: :overhead | :scalar | :commit_scalar | :blob_scalar | :l1_base_fee | :l1_blob_base_fee,
          value: non_neg_integer()
        }

  @typedoc """
    * `block_number` - A block number of the transaction where the given parameter was changed.
    * `transaction_index` - An index of the transaction (within the block) where the given parameter was changed.
    * `name` - A name of the parameter (can be one of: `overhead`, `scalar`, `commit_scalar`, `blob_scalar`, `l1_base_fee`, `l1_blob_base_fee`).
    * `value` - A new value of the parameter.
  """
  @primary_key false
  typed_schema "scroll_l1_fee_params" do
    field(:block_number, :integer, primary_key: true)
    field(:transaction_index, :integer, primary_key: true)

    field(:name, Ecto.Enum,
      values: [:overhead, :scalar, :commit_scalar, :blob_scalar, :l1_base_fee, :l1_blob_base_fee],
      primary_key: true
    )

    field(:value, :integer)

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = params, attrs \\ %{}) do
    params
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint([:block_number, :transaction_index])
  end

  @doc """
    Calculates gas used on L1 for the specified L2 transaction.
    The returning value depends on the transaction block number:
    if that's after Curie upgrade, the function returns 0 as all transactions are put into blob.
    Otherwise, the value is calculated based on transaction data (and includes the given overhead).
    See https://github.com/scroll-tech/go-ethereum/blob/9ec83a509ac7f6dd2d0beb054eb14c19f3e67a72/rollup/fees/rollup_fee.go#L171-L195
    for the implementation and https://scroll.io/blog/compressing-the-gas-scrolls-curie-upgrade for the Curie upgrade description.

    ## Parameters
    - `transaction`: Transaction structure containing block number and transaction data.
    - `l1_fee_overhead`: The overhead to add to the gas used in case the transaction was created before Curie upgrade.

    ## Returns
    - Calculated L1 gas used value (can be 0).
  """
  @spec l1_gas_used(Transaction.t(), non_neg_integer()) :: non_neg_integer()
  def l1_gas_used(transaction, l1_fee_overhead) do
    if transaction.block_number > Application.get_all_env(:explorer)[__MODULE__][:curie_upgrade_block] do
      0
    else
      total =
        transaction.input.bytes
        |> :binary.bin_to_list()
        |> Enum.reduce(0, fn byte, acc ->
          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          if byte == 0 do
            acc + 4
          else
            acc + 16
          end
        end)

      total + l1_fee_overhead + 4 * 16
    end
  end

  @doc """
    Reads the block number from the `last_fetched_counters` table which was
    the last handled L2 block on the previous launch of Indexer.Fetcher.Scroll.L1FeeParam module.

    ## Returns
    - The last L2 block number.
    - Zero if this is the first launch of the module.
  """
  @spec last_l2_block_number() :: non_neg_integer()
  def last_l2_block_number do
    @counter_type
    |> LastFetchedCounter.get()
    |> Decimal.to_integer()
  end

  @doc """
    Updates the last handled L2 block by the Indexer.Fetcher.Scroll.L1FeeParam module.
    The new block number is written to the `last_fetched_counters` table.

    ## Parameters
    - `block_number`: The number of the L2 block.

    ## Returns
    - nothing
  """
  @spec set_last_l2_block_number(non_neg_integer()) :: any()
  def set_last_l2_block_number(block_number) do
    LastFetchedCounter.upsert(%{
      counter_type: @counter_type,
      value: block_number
    })
  end
end
