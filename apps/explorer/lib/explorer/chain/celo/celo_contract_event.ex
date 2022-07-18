defmodule Explorer.Chain.CeloContractEvent do
  @moduledoc """
    Representing an event emitted from a Celo core contract.
  """
  require Logger

  use Explorer.Schema
  import Ecto.Query

  alias Explorer.Celo.ContractEvents.Common
  alias Explorer.Chain.Hash
  alias Explorer.Chain.Hash.Address

  @type t :: %__MODULE__{
          name: String.t(),
          topic: String.t(),
          log_index: non_neg_integer(),
          block_number: non_neg_integer(),
          contract_address_hash: Hash.Address.t(),
          transaction_hash: Hash.Full.t(),
          params: map()
        }

  @attrs ~w( name contract_address_hash transaction_hash log_index params topic block_number)a
  @required ~w( name contract_address_hash log_index topic block_number)a

  @primary_key false
  schema "celo_contract_events" do
    field(:block_number, :integer, primary_key: true)
    field(:log_index, :integer, primary_key: true)
    field(:name, :string)
    field(:topic, :string)
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

  def schemaless_upsert do
    from(cce in "celo_contract_events",
      update: [
        set: [
          name: fragment("EXCLUDED.name"),
          topic: fragment("EXCLUDED.topic"),
          params: fragment("EXCLUDED.params"),
          contract_address_hash: fragment("EXCLUDED.contract_address_hash"),
          transaction_hash: fragment("EXCLUDED.transaction_hash")
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.name, EXCLUDED.topic, EXCLUDED.params, EXCLUDED.contract_address_hash, EXCLUDED.transaction_hash) IS DISTINCT FROM (?, ?, ?, ?, ?)",
          cce.name,
          cce.topic,
          cce.params,
          cce.contract_address_hash,
          cce.transaction_hash
        )
    )
  end

  def default_upsert do
    from(cce in __MODULE__,
      update: [
        set: [
          name: fragment("EXCLUDED.name"),
          topic: fragment("EXCLUDED.topic"),
          params: fragment("EXCLUDED.params"),
          contract_address_hash: fragment("EXCLUDED.contract_address_hash"),
          transaction_hash: fragment("EXCLUDED.transaction_hash")
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.name, EXCLUDED.topic, EXCLUDED.params, EXCLUDED.contract_address_hash, EXCLUDED.transaction_hash) IS DISTINCT FROM (?, ?, ?, ?, ?)",
          cce.name,
          cce.topic,
          cce.params,
          cce.contract_address_hash,
          cce.transaction_hash
        )
    )
  end

  def conflict_target, do: [:block_number, :log_index]

  def query_by_voter_param(query, voter_address_hash) do
    voter_address_for_pg = Common.fa(voter_address_hash)

    from(c in query,
      where: fragment("? ->> ? = ?", c.params, "account", ^voter_address_for_pg)
    )
  end

  def query_by_group_param(query, group_address_hash) do
    group_address_for_pg = Common.fa(group_address_hash)

    from(c in query,
      where: fragment("? ->> ? = ?", c.params, "group", ^group_address_for_pg)
    )
  end

  def query_by_validator_param(query, validator_address_hash) do
    validator_address_for_pg = Common.fa(validator_address_hash)

    from(c in query,
      where: fragment("? ->> ? = ?", c.params, "validator", ^validator_address_for_pg)
    )
  end
end
