defmodule Explorer.Chain.CeloContractEvent do
  @moduledoc """
    Representing an event emitted from a Celo core contract.
  """
  require Logger

  use Explorer.Schema
  import Ecto.Query

  alias Explorer.Celo.ContractEvents.EventMap
  alias Explorer.Chain.Hash
  alias Explorer.Chain.Hash.Address
  alias Explorer.Repo

  @type t :: %__MODULE__{
          block_hash: Hash.Full.t(),
          name: String.t(),
          log_index: non_neg_integer(),
          contract_address_hash: Hash.Address.t(),
          transaction_hash: Hash.Address.t(),
          params: map()
        }

  @attrs ~w( name contract_address_hash transaction_hash block_hash log_index params)a
  @required ~w( name contract_address_hash block_hash log_index)a

  @primary_key false
  schema "celo_contract_events" do
    field(:block_hash, Hash.Full, primary_key: true)
    field(:log_index, :integer, primary_key: true)
    field(:name, :string)
    field(:params, :map)
    field(:contract_address_hash, Address)
    field(:transaction_hash, Address)

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = item, attrs) do
    item
    |> cast(attrs, @attrs)
    |> validate_required(@required)
  end

  @doc "returns ids of entries in log table that contain events not yet included in CeloContractEvents table"
  def fetch_unprocessed_log_ids_query(topics) when is_list(topics) do
    from(l in "logs",
      select: {l.block_hash, l.index},
      left_join: cce in CeloContractEvent,
      on: {cce.block_hash, cce.log_index} == {l.block_hash, l.index},
      where: l.first_topic in ^topics and is_nil(cce.block_hash),
      order_by: [asc: l.block_number, asc: l.index]
    )
  end

  @throttle_ms 100
  @batch_size 1000
  def insert_unprocessed_events(events, batch_size \\ @batch_size) do
    # fetch ids of missing events
    ids =
      events
      |> Enum.map(& &1.topic)
      |> fetch_unprocessed_log_ids_query()
      |> Repo.all()

    # batch convert and insert new rows
    ids
    |> Enum.chunk_every(batch_size)
    |> Enum.map(fn batch ->
      to_insert =
        batch
        |> fetch_params()
        |> Repo.all()
        |> EventMap.rpc_to_event_params()

      result = Repo.insert_all(__MODULE__, to_insert, returning: [:block_hash, :log_index])

      Process.sleep(@throttle_ms)
      result
    end)
  end

  def fetch_params(ids) do
    from(
      l in "logs",
      select: %{
        first_topic: l.first_topic,
        second_topic: l.second_topic,
        third_topic: l.third_topic,
        fourth_topic: l.fourth_topic,
        data: l.data,
        address_hash: l.address_hash,
        transaction_hash: l.transaction_hash,
        block_number: l.block_number,
        block_hash: l.block_hash,
        index: l.index
      },
      join: v in fragment("(VALUES ?) AS j(bytea block_hash, int index)", ^ids),
      on: v.block_hash == l.block_hash and v.index == l.index
    )
  end
end
