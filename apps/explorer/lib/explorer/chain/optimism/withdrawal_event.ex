defmodule Explorer.Chain.Optimism.WithdrawalEvent do
  @moduledoc "Models Optimism withdrawal event."

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @required_attrs ~w(withdrawal_hash l1_event_type l1_timestamp l1_transaction_hash l1_block_number)a
  @optional_attrs ~w(game_index game_address_hash)a

  @typedoc """
    Descriptor of the withdrawal event:
    * `withdrawal_hash` - A withdrawal hash.
    * `l1_event_type` - A type of withdrawal event: `WithdrawalProven` or `WithdrawalFinalized`.
    * `l1_timestamp` - A timestamp of when the withdrawal event appeared.
    * `l1_transaction_hash` - An hash of L1 transaction that contains the event.
    * `l1_block_number` - An L1 block number of the L1 transaction.
    * `game_index` - An index of a dispute game (if available in L1 transaction input) when
      the withdrawal is proven. Equals to `nil` if not available.
    * `game_address_hash` - Contract address of a dispute game (if available in L1 transaction input) when
      the withdrawal is proven. Equals to `nil` if not available.
  """
  @type to_import :: %{
          withdrawal_hash: Hash.t(),
          l1_event_type: String.t(),
          l1_timestamp: DateTime.t(),
          l1_transaction_hash: Hash.t(),
          l1_block_number: non_neg_integer(),
          game_index: non_neg_integer(),
          game_address_hash: Hash.t()
        }

  @typedoc """
    * `withdrawal_hash` - A withdrawal hash.
    * `l1_event_type` - A type of withdrawal event: `WithdrawalProven` or `WithdrawalFinalized`.
    * `l1_timestamp` - A timestamp of when the withdrawal event appeared.
    * `l1_transaction_hash` - An hash of L1 transaction that contains the event.
    * `l1_block_number` - An L1 block number of the L1 transaction.
    * `game_index` - An index of a dispute game (if available in L1 transaction input) when
      the withdrawal is proven. Equals to `nil` if not available.
    * `game_address_hash` - Contract address of a dispute game (if available in L1 transaction input) when
      the withdrawal is proven. Equals to `nil` if not available.
  """
  @primary_key false
  typed_schema "op_withdrawal_events" do
    field(:withdrawal_hash, Hash.Full, primary_key: true)
    field(:l1_event_type, Ecto.Enum, values: [:WithdrawalProven, :WithdrawalFinalized], primary_key: true)
    field(:l1_timestamp, :utc_datetime_usec)
    field(:l1_transaction_hash, Hash.Full, primary_key: true)
    field(:l1_block_number, :integer)
    field(:game_index, :integer)
    field(:game_address_hash, Hash.Address)

    timestamps()
  end

  def changeset(%__MODULE__{} = withdrawal_events, attrs \\ %{}) do
    withdrawal_events
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
  end

  @doc """
    Forms a query to find the last Withdrawal L1 event's block number and transaction hash.
    Used by the `Indexer.Fetcher.Optimism.WithdrawalEvent` module.

    ## Returns
    - A query which can be used by the `Repo.one` function.
  """
  @spec last_event_l1_block_number_query() :: Ecto.Queryable.t()
  def last_event_l1_block_number_query do
    from(event in __MODULE__,
      select: {event.l1_block_number, event.l1_transaction_hash},
      order_by: [desc: event.l1_timestamp],
      limit: 1
    )
  end

  @doc """
    Forms a query to remove all Withdrawal L1 events related to the specified L1 block number.
    Used by the `Indexer.Fetcher.Optimism.WithdrawalEvent` module.

    ## Parameters
    - `l1_block_number`: The L1 block number for which the events should be removed
                         from the `op_withdrawal_events` database table.

    ## Returns
    - A query which can be used by the `delete_all` function.
  """
  @spec remove_events_query(non_neg_integer()) :: Ecto.Queryable.t()
  def remove_events_query(l1_block_number) do
    from(event in __MODULE__, where: event.l1_block_number == ^l1_block_number)
  end
end
