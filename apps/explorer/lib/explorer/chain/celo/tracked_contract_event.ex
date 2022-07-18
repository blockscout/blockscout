defmodule Explorer.Chain.Celo.TrackedContractEvent do
  @moduledoc """
    Representing a contract event emitted from a verified `smart_contract` and with a matching `contract_event_tracking` entry
  """
  require Logger

  alias __MODULE__
  alias Explorer.Chain.Celo.ContractEventTracking
  alias Explorer.Chain.{Hash, Log, SmartContract, Transaction}
  alias Explorer.Chain.Hash.Address
  alias Explorer.Repo
  alias Explorer.SmartContract.Helper, as: SmartContractHelper

  use Explorer.Schema
  import Ecto.Query

  @type t :: %__MODULE__{
          block_number: integer(),
          log_index: integer(),
          name: String.t(),
          topic: String.t(),
          params: map(),
          transaction_hash: Hash.Full.t(),
          contract_address_hash: Hash.Address.t()
        }

  @attrs ~w(
          block_number log_index name topic params transaction_hash contract_address_hash contract_event_tracking_id
        )a

  @required ~w(
          block_number log_index name topic params contract_address_hash contract_event_tracking_id
        )a

  @primary_key false
  schema "clabs_tracked_contract_events" do
    field(:block_number, :integer, primary_key: true)
    field(:log_index, :integer, primary_key: true)

    field(:topic, :string)
    field(:name, :string)
    field(:params, :map)

    belongs_to(:contract_event_tracking, ContractEventTracking)

    belongs_to(:smart_contract, SmartContract,
      foreign_key: :contract_address_hash,
      references: :address_hash,
      type: Hash.Address
    )

    belongs_to(:transaction, Transaction, foreign_key: :transaction_hash, references: :hash, type: Hash.Full)

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def from(
        attrs,
        %Log{address_hash: contract_hash, first_topic: topic} = log,
        %ContractEventTracking{id: id, topic: topic, name: name, address: %{hash: contract_hash}}
      ) do
    log_properties = %{log_index: log.index, block_number: log.block_number, transaction_hash: log.transaction_hash}
    other_properties = %{topic: topic, name: name, contract_address_hash: contract_hash, contract_event_tracking_id: id}

    attrs
    |> Map.merge(log_properties)
    |> Map.merge(other_properties)
    |> then(&changeset(%__MODULE__{}, &1))
  end

  def changeset(%__MODULE__{} = item, attrs) do
    item
    |> cast(attrs, @attrs)
    |> validate_required(@attrs)
  end
end
