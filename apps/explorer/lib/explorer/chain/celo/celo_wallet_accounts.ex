defmodule Explorer.Chain.CeloWalletAccounts do
  @moduledoc """
  Datatype for storing latest Celo Wallet Accounts associations.
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash}

  @typedoc """
  """

  @type t :: %__MODULE__{
          wallet_address_hash: Hash.Address.t(),
          account_address_hash: Hash.Address.t(),
          block_number: integer
        }

  schema "celo_wallet_accounts" do
    field(:block_number, :integer)

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
  end
end
