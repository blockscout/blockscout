defmodule Explorer.Chain.ZkSync.TransactionDetails do
  @moduledoc "Models an ZKsync specific transaction details which received via ZKsync JSON-RPC API"

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @optional_attrs ~w()a
  @required_attrs ~w(hash received_at is_l1_originated, gas_per_pubdata, fee)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  @type t :: %__MODULE__{
          hash: Hash.t(),
          received_at: DateTime.t(),
          is_l1_originated: boolean(),
          gas_per_pubdata: decimal(),
          fee: decimal()
        }

  @typedoc """
   * `hash` - the hash of the transaction.
   * `received_at` - timestamp when the transaction was received.
   * `is_l1_originated` - Indicates whether the transaction originated on Layer 1.
   * `gas_per_pubdata` - gas amount per unit of public data for this transaction.
   * `fee` - transaction fee.
  """
  @primary_key false
  typed_schema "zksync_transaction_details" do
    field(:hash, Hash.Full, null: false)
    field(:received_at, :utc_datetime_usec, null: false)
    field(:is_l1_originated, :boolean, default: false, null: false)
    field(:gas_per_pubdata, :decimal, null: false)
    field(:fee, :decimal, null: false)

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = details, attrs \\ %{}) do
    details
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
  end
end
