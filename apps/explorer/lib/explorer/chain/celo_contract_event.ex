defmodule Explorer.Chain.CeloContractEvent do
  @moduledoc """
    Representing an event emitted from a Celo core contract.
  """
  require Logger

  use Explorer.Schema
  import Ecto.Query

  alias Explorer.Celo.ContractEvents.EventMap
  alias Explorer.Chain.{Hash, Log}
  alias Explorer.Chain.Hash.Address
  alias Explorer.Repo

  @type t :: %__MODULE__{
          block_hash: Hash.Full.t(),
          name: String.t(),
          log_index: non_neg_integer(),
          contract_address_hash: Hash.Address.t(),
          transaction_hash: Hash.Full.t(),
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
    field(:transaction_hash, Hash.Full)

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
      left_join: cce in __MODULE__,
      on: {cce.block_hash, cce.log_index} == {l.block_hash, l.index},
      where: l.first_topic in ^topics and is_nil(cce.block_hash),
      order_by: [asc: l.block_number, asc: l.index]
    )
  end

  @throttle_ms 100
  @batch_size 1000
  @doc "Insert events as yet unprocessed from Log table into CeloContractEvents"
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
        |> set_timestamps()

      result = Repo.insert_all(__MODULE__, to_insert, returning: [:block_hash, :log_index])

      Process.sleep(@throttle_ms)
      result
    end)
  end

  def fetch_params(ids) do
    # convert list of {block_hash, index} tuples to two lists of [block_hash] and [index] because ecto can't handle
    # direct tuple comparisons with a WHERE IN clause
    {blocks, indices} =
      ids
      |> Enum.reduce([[], []], fn {block, index}, [blocks, indices] ->
        [[block | blocks], [index | indices]]
      end)
      |> then(fn [blocks, indices] -> {Enum.reverse(blocks), Enum.reverse(indices)} end)

    from(
      l in Log,
      join: v in fragment("SELECT * FROM unnest(?::bytea[], ?::int[]) AS v(block_hash,index)", ^blocks, ^indices),
      on: v.block_hash == l.block_hash and v.index == l.index
    )
  end

  defp set_timestamps(events) do
    # Repo.insert_all does not handle timestamps, set explicitly here
    timestamp = Timex.now()

    Enum.map(events, fn e ->
      e
      |> Map.put(:inserted_at, timestamp)
      |> Map.put(:updated_at, timestamp)
    end)
  end
end
