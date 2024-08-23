defmodule Explorer.Chain.Optimism.Deposit do
  @moduledoc "Models a deposit for Optimism."

  use Explorer.Schema

  import Explorer.Chain, only: [join_association: 3, select_repo: 1]

  alias Explorer.Chain.{Hash, Transaction}
  alias Explorer.PagingOptions

  @default_paging_options %PagingOptions{page_size: 50}

  @required_attrs ~w(l1_block_number l1_transaction_hash l1_transaction_origin l2_transaction_hash)a
  @optional_attrs ~w(l1_block_timestamp)a
  @allowed_attrs @required_attrs ++ @optional_attrs

  @type t :: %__MODULE__{
          l1_block_number: non_neg_integer(),
          l1_block_timestamp: DateTime.t(),
          l1_transaction_hash: Hash.t(),
          l1_transaction_origin: Hash.t(),
          l2_transaction_hash: Hash.t(),
          l2_transaction: %Ecto.Association.NotLoaded{} | Transaction.t()
        }

  @primary_key false
  schema "op_deposits" do
    field(:l1_block_number, :integer)
    field(:l1_block_timestamp, :utc_datetime_usec)
    field(:l1_transaction_hash, Hash.Full)
    field(:l1_transaction_origin, Hash.Address)

    belongs_to(:l2_transaction, Transaction,
      foreign_key: :l2_transaction_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full
    )

    timestamps()
  end

  def changeset(%__MODULE__{} = deposit, attrs \\ %{}) do
    deposit
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:l2_transaction_hash)
  end

  def last_deposit_l1_block_number_query do
    from(d in __MODULE__,
      select: {d.l1_block_number, d.l1_transaction_hash},
      order_by: [desc: d.l1_block_number],
      limit: 1
    )
  end

  @doc """
  Lists `t:Explorer.Chain.Optimism.Deposit.t/0`'s' in descending order based on l1_block_number and l2_transaction_hash.

  """
  @spec list :: [__MODULE__.t()]
  def list(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    case paging_options do
      %PagingOptions{key: {0, _l2_tx_hash}} ->
        []

      _ ->
        base_query =
          from(d in __MODULE__,
            order_by: [desc: d.l1_block_number, desc: d.l2_transaction_hash]
          )

        base_query
        |> join_association(:l2_transaction, :required)
        |> page_deposits(paging_options)
        |> limit(^paging_options.page_size)
        |> select_repo(options).all()
    end
  end

  defp page_deposits(query, %PagingOptions{key: nil}), do: query

  defp page_deposits(query, %PagingOptions{key: {block_number, l2_tx_hash}}) do
    from(d in query,
      where: d.l1_block_number < ^block_number,
      or_where: d.l1_block_number == ^block_number and d.l2_transaction_hash < ^l2_tx_hash
    )
  end
end
