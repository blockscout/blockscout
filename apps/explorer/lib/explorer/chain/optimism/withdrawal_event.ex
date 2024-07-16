defmodule Explorer.Chain.Optimism.WithdrawalEvent do
  @moduledoc "Models Optimism withdrawal event."

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @required_attrs ~w(withdrawal_hash l1_event_type l1_timestamp l1_transaction_hash l1_block_number)a
  @optional_attrs ~w(game_index)a

  @typedoc """
    * `withdrawal_hash` - A withdrawal hash.
    * `l1_event_type` - A type of withdrawal event: `WithdrawalProven` or `WithdrawalFinalized`.
    * `l1_timestamp` - A timestamp of when the withdrawal event appeared.
    * `l1_transaction_hash` - An hash of L1 transaction that contains the event.
    * `l1_block_number` - An L1 block number of the L1 transaction.
    * `game_index` - An index of a dispute game (if available in L1 transaction input) when
      the withdrawal is proven. Equals to `nil` if not available.
  """
  @primary_key false
  typed_schema "op_withdrawal_events" do
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
