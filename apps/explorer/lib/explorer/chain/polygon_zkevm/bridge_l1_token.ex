defmodule Explorer.Chain.PolygonZkevm.BridgeL1Token do
  @moduledoc "Models a bridge token on L1 for Polygon zkEVM."

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @optional_attrs ~w(decimals symbol)a

  @required_attrs ~w(address)a

  @type t :: %__MODULE__{
          address: Hash.Address.t(),
          decimals: non_neg_integer() | nil,
          symbol: String.t() | nil
        }

  @primary_key {:id, :id, autogenerate: true}
  schema "polygon_zkevm_bridge_l1_tokens" do
    field(:address, Hash.Address)
    field(:decimals, :integer)
    field(:symbol, :string)

    timestamps()
  end

  @doc """
    Checks that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = tokens, attrs \\ %{}) do
    tokens
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:id)
  end
end
