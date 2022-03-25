defmodule Explorer.Chain.CeloCoreContract do
  @moduledoc """
    A specific address in the blockchain representing a "Core Contract" as defined by the Celo protocol
  """
  require Logger

  use Explorer.Schema
  alias Explorer.Chain.Hash
  alias Explorer.Chain.Hash.Address

  @type t :: %__MODULE__{
          name: String.t(),
          log_index: non_neg_integer(),
          block_number: non_neg_integer(),
          address_hash: Hash.Address.t()
        }

  @attrs ~w(name log_index block_number address_hash)a
  @required ~w(name log_index block_number address_hash)a

  @primary_key false
  schema "celo_core_contracts" do
    field(:address_hash, Address, primary_key: true)
    field(:name, :string)
    field(:block_number, :integer)
    field(:log_index, :integer)

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = item, attrs) do
    item
    |> cast(attrs, @attrs)
    |> validate_required(@required)
  end
end
