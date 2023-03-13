defmodule Explorer.Chain.OptimismDeposit do
  @moduledoc "Models a deposit for Optimism."

  use Explorer.Schema

  alias Explorer.Chain.{Hash, Transaction}

  @required_attrs ~w(l1_block_number l1_transaction_hash l1_transaction_origin l2_transaction_hash)a
  @optional_attrs ~w(l1_block_timestamp)a
  @allowed_attrs @required_attrs ++ @optional_attrs

  @type t :: %__MODULE__{
          l1_block_number: non_neg_integer(),
          l1_block_timestamp: DateTime.t(),
          l1_transaction_hash: Hash.t(),
          l1_transaction_origin: Hash.t(),
          l2_transaction_hash: Hash.t()
        }

  @primary_key false
  schema "op_deposits" do
    field(:l1_block_number, :integer)
    field(:l1_block_timestamp, :utc_datetime_usec)
    field(:l1_transaction_hash, Hash.Full)
    field(:l1_transaction_origin, Hash.Address)

    belongs_to(:transaction, Transaction,
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
  end

  def last_deposit_l1_block_number_query do
    from(d in __MODULE__,
      select: {d.l1_block_number, d.l1_transaction_hash},
      order_by: [desc: d.l1_block_number],
      limit: 1
    )
  end
end
