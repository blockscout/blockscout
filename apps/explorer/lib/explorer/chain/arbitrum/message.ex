defmodule Explorer.Chain.Arbitrum.Message do
  @moduledoc "Models an L1<->L2 messages on Arbitrum."

  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash}

  @optional_attrs ~w(originator_address originating_tx_hash origination_timestamp originating_tx_blocknum completion_tx_hash)a

  @required_attrs ~w(direction message_id status)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @type t :: %__MODULE__{
          direction: String.t(),
          message_id: non_neg_integer(),
          originator_address: Hash.Address.t() | nil,
          originating_tx_hash: Hash.t() | nil,
          origination_timestamp: DateTime.t() | nil,
          originating_tx_blocknum: Block.block_number() | nil,
          completion_tx_hash: Hash.t() | nil,
          status: String.t()
        }

  @primary_key false
  schema "arbitrum_crosslevel_messages" do
    field(:direction, Ecto.Enum, values: [:to_l2, :from_l2], primary_key: true)
    field(:message_id, :integer, primary_key: true)
    field(:originator_address, Hash.Address)
    field(:originating_tx_hash, Hash.Full)
    field(:origination_timestamp, :utc_datetime_usec)
    field(:originating_tx_blocknum, :integer)
    field(:completion_tx_hash, Hash.Full)
    field(:status, Ecto.Enum, values: [:initiated, :confirmed, :relayed])

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = txn, attrs \\ %{}) do
    txn
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint([:direction, :message_id])
  end
end
