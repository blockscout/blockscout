defmodule Explorer.Chain.Zkevm.Bridge do
  @moduledoc "Models a bridge operation for Polygon zkEVM."

  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash}

  @optional_attrs ~w(l1_transaction_hash l2_transaction_hash l1_token_address l1_token_decimals l1_token_symbol block_number block_timestamp)a

  @required_attrs ~w(type index amount)a

  @type t :: %__MODULE__{
          type: String.t(),
          index: non_neg_integer(),
          l1_transaction_hash: Hash.t() | nil,
          l2_transaction_hash: Hash.t() | nil,
          l1_token_address: Hash.Address.t() | nil,
          l1_token_decimals: non_neg_integer() | nil,
          l1_token_symbol: String.t() | nil,
          amount: Decimal.t(),
          block_number: Block.block_number() | nil,
          block_timestamp: DateTime.t() | nil
        }

  @primary_key false
  schema "zkevm_bridge" do
    field(:type, Ecto.Enum, values: [:deposit, :withdrawal], primary_key: true)
    field(:index, :integer, primary_key: true)
    field(:l1_transaction_hash, Hash.Full)
    field(:l2_transaction_hash, Hash.Full)
    field(:l1_token_address, Hash.Address)
    field(:l1_token_decimals, :integer)
    field(:l1_token_symbol, :string)
    field(:amount, :decimal)
    field(:block_number, :integer)
    field(:block_timestamp, :utc_datetime_usec)

    timestamps()
  end

  @doc """
    Checks that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = operations, attrs \\ %{}) do
    operations
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint([:type, :index])
  end
end
