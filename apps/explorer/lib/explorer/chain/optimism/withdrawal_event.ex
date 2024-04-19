defmodule Explorer.Chain.Optimism.WithdrawalEvent do
  @moduledoc "Models Optimism withdrawal event."

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @required_attrs ~w(withdrawal_hash l1_event_type l1_timestamp l1_transaction_hash l1_block_number)a
  @optional_attrs ~w(game_index)a

  @type t :: %__MODULE__{
          withdrawal_hash: Hash.t(),
          l1_event_type: String.t(),
          l1_timestamp: DateTime.t(),
          l1_transaction_hash: Hash.t(),
          l1_block_number: non_neg_integer(),
          game_index: non_neg_integer() | nil
        }

  @primary_key false
  schema "op_withdrawal_events" do
    field(:withdrawal_hash, Hash.Full, primary_key: true)
    field(:l1_event_type, Ecto.Enum, values: [:WithdrawalProven, :WithdrawalFinalized], primary_key: true)
    field(:l1_timestamp, :utc_datetime_usec)
    field(:l1_transaction_hash, Hash.Full)
    field(:l1_block_number, :integer)
    field(:game_index, :integer)

    timestamps()
  end

  def changeset(%__MODULE__{} = withdrawal_events, attrs \\ %{}) do
    withdrawal_events
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
  end
end
