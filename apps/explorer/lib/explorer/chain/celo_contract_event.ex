defmodule Explorer.Chain.CeloContractEvent do
  @moduledoc """
    Representing an event emitted from a Celo core contract.
  """
  require Logger

  use Explorer.Schema

  alias Explorer.Chain.Hash
  alias Explorer.Chain.Hash.Address

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
    field(:name, :string)
    field(:params, :map)
    field(:log_index, :integer)
    field(:contract_address_hash, Address)
    field(:transaction_hash, Address)
    field(:block_hash, Hash.Full)

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = item, attrs) do
    item
    |> cast(attrs, @attrs)
    |> validate_required(@required)
  end
end
