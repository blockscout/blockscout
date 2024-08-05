defmodule Explorer.Chain.Arbitrum.Message do
  @moduledoc """
    Models an L1<->L2 messages on Arbitrum.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Arbitrum.Messages

    Migrations:
    - Explorer.Repo.Arbitrum.Migrations.CreateArbitrumTables
  """

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @optional_attrs ~w(originator_address originating_transaction_hash origination_timestamp originating_transaction_block_number completion_transaction_hash)a

  @required_attrs ~w(direction message_id status)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  Descriptor of the L1<->L2 message on Arbitrum rollups:
    * `direction` - The direction of the message: `:to_l2` or `:from_l2`.
    * `message_id` - The ID of the message used for referencing.
    * `originator_address` - The address of the message originator. The fields
                             related to the origination can be `nil` if a completion
                             transaction is discovered when the originating
                             transaction is not indexed yet.
    * `originating_transaction_hash` - The hash of the originating transaction.
    * `origination_timestamp` - The timestamp of the origination.
    * `originating_transaction_block_number` - The number of the block where the
                                               originating transaction is included.
    * `completion_transaction_hash` - The hash of the completion transaction.
    * `status` - The status of the message: `:initiated`, `:sent`, `:confirmed`, `:relayed`
  """
  @type to_import :: %{
          direction: :to_l2 | :from_l2,
          message_id: non_neg_integer(),
          originator_address: binary() | nil,
          originating_transaction_hash: binary() | nil,
          origination_timestamp: DateTime.t() | nil,
          originating_transaction_block_number: non_neg_integer() | nil,
          completion_transaction_hash: binary() | nil,
          status: :initiated | :sent | :confirmed | :relayed
        }

  @typedoc """
    * `direction` - The direction of the message: `:to_l2` or `:from_l2`.
    * `message_id` - The ID of the message used for referencing.
    * `originator_address` - The address of the message originator. The fields
                             related to the origination can be `nil` if a completion
                             transaction is discovered when the originating
                            transaction is not indexed yet.
    * `originating_transaction_hash` - The hash of the originating transaction.
    * `origination_timestamp` - The timestamp of the origination.
    * `originating_transaction_block_number` - The number of the block where the
                                               originating transaction is included.
    * `completion_transaction_hash` - The hash of the completion transaction.
    * `status` - The status of the message: `:initiated`, `:sent`, `:confirmed`, `:relayed`.
  """
  @primary_key false
  typed_schema "arbitrum_crosslevel_messages" do
    field(:direction, Ecto.Enum, values: [:to_l2, :from_l2], primary_key: true)
    field(:message_id, :integer, primary_key: true)
    field(:originator_address, Hash.Address)
    field(:originating_transaction_hash, Hash.Full)
    field(:origination_timestamp, :utc_datetime_usec)
    field(:originating_transaction_block_number, :integer)
    field(:completion_transaction_hash, Hash.Full)
    field(:status, Ecto.Enum, values: [:initiated, :sent, :confirmed, :relayed])

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
