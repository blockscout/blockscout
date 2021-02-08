defmodule Explorer.Chain.CeloWallet do
  @moduledoc """
  Data type and schema for Celo wallet addresses
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash}

  @typedoc """
  * `account_address_hash` - account address.
  * `wallet_address_hash` - corresponding wallet address.
  * `block_number` - block where the mapping was set.
  """

  @type t :: %__MODULE__{
          account_address_hash: Hash.Address.t(),
          wallet_address_hash: Hash.Address.t(),
          block_number: integer
        }

  @attrs ~w(
          account_address_hash wallet_address_hash block_number
        )a

  @required_attrs ~w(
          account_address_hash wallet_address_hash block_number
        )a

  schema "celo_wallets" do
    belongs_to(
      :account,
      Address,
      foreign_key: :account_address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(
      :wallet,
      Address,
      foreign_key: :wallet_address_hash,
      references: :hash,
      type: Hash.Address
    )

    field(:block_number, :integer)

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = celo_wallets, attrs) do
    celo_wallets
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:celo_wallet_key, name: :celo_wallets_wallet_address_hash_account_address_hash_index)
  end
end
