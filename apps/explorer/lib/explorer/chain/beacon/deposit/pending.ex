defmodule Explorer.Chain.Beacon.Deposit.Pending do
  @moduledoc """
  Models a pending deposit in the beacon chain.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Data, Wei}

  @primary_key false
  typed_schema "temp_beacon_pending_deposits" do
    field(:pubkey, Data, null: false)
    field(:withdrawal_credentials, Data, null: false)
    field(:amount, Wei, null: false)
    field(:signature, Data, null: false)
    field(:block_timestamp, :utc_datetime_usec, null: false)
  end

  @doc """
  Cast and validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(deposit, attrs) do
    deposit
    |> cast(attrs, [:pubkey, :withdrawal_credentials, :amount, :signature, :block_timestamp])
    |> validate_required([:pubkey, :withdrawal_credentials, :amount, :signature, :block_timestamp])
  end
end
