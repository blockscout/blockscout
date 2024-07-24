defmodule Explorer.Chain.Scroll.L1FeeParam do
  @moduledoc "Models an L1 fee parameter for Scroll."

  use Explorer.Schema

  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Chain.Transaction

  @required_attrs ~w(block_number tx_index name value)a

  @typedoc """
    * `block_number` - A block number of the transaction where the given parameter was changed.
    * `tx_index` - An index of the transaction (within the block) where the given parameter was changed.
    * `name` - A name of the parameter (can be one of: `overhead`, `scalar`, `commit_scalar`, `blob_scalar`, `l1_base_fee`, `l1_blob_base_fee`).
    * `value` - A new value of the parameter.
  """
  @primary_key false
  typed_schema "scroll_l1_fee_params" do
    field(:block_number, :integer, primary_key: true)
    field(:tx_index, :integer, primary_key: true)

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
    |> unique_constraint([:block_number, :tx_index])
  end

  @doc """
    Gets a value of the specified parameter for the given transaction from database.
    If a parameter is not defined for the transaction block number and index, the function returns `nil`.

    ## Parameters
    - `name`: A name of the parameter.
    - `transaction`: Transaction structure containing block number and transaction index within the block.
    - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - The parameter value, or `nil` if not defined.
  """
  @spec get_for_transaction(atom(), Transaction.t(), list()) :: non_neg_integer() | nil
  def get_for_transaction(name, transaction, options \\ [])
      when name in [:overhead, :scalar, :commit_scalar, :blob_scalar, :l1_base_fee, :l1_blob_base_fee] do
    query =
      from(p in __MODULE__,
        select: p.value,
        where:
          p.name == ^name and
            (p.block_number < ^transaction.block_number or
               (p.block_number == ^transaction.block_number and p.tx_index < ^transaction.index)),
        order_by: [desc: p.block_number, desc: p.tx_index],
        limit: 1
      )

    select_repo(options).one(query)
  end

  @doc """
    Calculates gas used on L1 for the specified L2 transaction.
    The returning value depends on the transaction block number:
    if that's after Curie upgrade, the function returns 0.
    Otherwise, the value is calculated based on transaction data (and includes the given overhead).

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
end
