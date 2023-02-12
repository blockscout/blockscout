defmodule Explorer.Chain.OptimismWithdrawalEvent do
  @moduledoc "Models Optimism withdrawal event."

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @required_attrs ~w(withdrawal_hash l1_event_type l1_timestamp l1_tx_hash l1_block_number)a

  @type t :: %__MODULE__{
          withdrawal_hash: Hash.t(),
          l1_event_type: String.t(),
          l1_timestamp: DateTime.t(),
          l1_tx_hash: Hash.t(),
          l1_block_number: non_neg_integer()
        }

  @primary_key false
  schema "op_withdrawal_events" do
    field(:withdrawal_hash, Hash.Full, primary_key: true)
    field(:l1_event_type, Ecto.Enum, values: [:WithdrawalProven, :WithdrawalFinalized], primary_key: true)
    field(:l1_timestamp, :utc_datetime_usec)
    field(:l1_tx_hash, Hash.Full)
    field(:l1_block_number, :integer)

    timestamps()
  end

  def changeset(%__MODULE__{} = withdrawal_events, attrs \\ %{}) do
    withdrawal_events
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end
end
