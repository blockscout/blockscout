defmodule Explorer.Chain.PolygonZkevm.Bridge do
  @moduledoc "Models a bridge operation for Polygon zkEVM."

  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash, Token}
  alias Explorer.Chain.PolygonZkevm.BridgeL1Token

  @optional_attrs ~w(l1_transaction_hash l2_transaction_hash l1_token_id l2_token_address block_number block_timestamp)a

  @required_attrs ~w(type index amount)a

  @type t :: %__MODULE__{
          type: String.t(),
          index: non_neg_integer(),
          l1_transaction_hash: Hash.t() | nil,
          l2_transaction_hash: Hash.t() | nil,
          l1_token: %Ecto.Association.NotLoaded{} | BridgeL1Token.t() | nil,
          l1_token_id: non_neg_integer() | nil,
          l1_token_address: Hash.Address.t() | nil,
          l2_token: %Ecto.Association.NotLoaded{} | Token.t() | nil,
          l2_token_address: Hash.Address.t() | nil,
          amount: Decimal.t(),
          block_number: Block.block_number() | nil,
          block_timestamp: DateTime.t() | nil
        }

  @primary_key false
  schema "polygon_zkevm_bridge" do
    field(:type, Ecto.Enum, values: [:deposit, :withdrawal], primary_key: true)
    field(:index, :integer, primary_key: true)
    field(:l1_transaction_hash, Hash.Full)
    field(:l2_transaction_hash, Hash.Full)
    belongs_to(:l1_token, BridgeL1Token, foreign_key: :l1_token_id, references: :id, type: :integer)
    field(:l1_token_address, Hash.Address)
    belongs_to(:l2_token, Token, foreign_key: :l2_token_address, references: :contract_address_hash, type: Hash.Address)
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
    |> foreign_key_constraint(:l1_token_id)
  end
end
