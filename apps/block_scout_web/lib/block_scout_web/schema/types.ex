defmodule BlockScoutWeb.Schema.Types do
  @moduledoc false

  use Absinthe.Schema.Notation

  import Absinthe.Resolution.Helpers

  import_types(Absinthe.Type.Custom)
  import_types(BlockScoutWeb.Schema.Scalars)

  @desc """
  A stored representation of a Web3 address.
  """
  object :address do
    field(:hash, :address_hash)
    field(:fetched_coin_balance, :wei)
    field(:fetched_coin_balance_block_number, :integer)
    field(:contract_code, :data)

    field :smart_contract, :smart_contract do
      resolve(dataloader(:db, :smart_contract))
    end
  end

  @desc """
  A package of data that contains zero or more transactions, the hash of the previous block ("parent"), and optionally
  other data. Because each block (except for the initial "genesis block") points to the previous block, the data
  structure that they form is called a "blockchain".
  """
  object :block do
    field(:hash, :full_hash)
    field(:consensus, :boolean)
    field(:difficulty, :decimal)
    field(:gas_limit, :decimal)
    field(:gas_used, :decimal)
    field(:nonce, :nonce_hash)
    field(:number, :integer)
    field(:size, :integer)
    field(:timestamp, :datetime)
    field(:total_difficulty, :decimal)
    field(:miner_hash, :address_hash)
    field(:parent_hash, :full_hash)
  end

  @desc """
  The representation of a verified Smart Contract.

  "A contract in the sense of Solidity is a collection of code (its functions)
  and data (its state) that resides at a specific address on the Ethereum
  blockchain."
  http://solidity.readthedocs.io/en/v0.4.24/introduction-to-smart-contracts.html
  """
  object :smart_contract do
    field(:name, :string)
    field(:compiler_version, :string)
    field(:optimization, :boolean)
    field(:contract_source_code, :string)
    field(:abi, :json)
    field(:address_hash, :address_hash)
  end

  @desc """
  Models a Web3 transaction.
  """
  object :transaction do
    field(:hash, :full_hash)
    field(:block_number, :integer)
    field(:cumulative_gas_used, :decimal)
    field(:error, :string)
    field(:gas, :decimal)
    field(:gas_price, :wei)
    field(:gas_used, :decimal)
    field(:index, :integer)
    field(:input, :string)
    field(:nonce, :nonce_hash)
    field(:r, :decimal)
    field(:s, :decimal)
    field(:status, :status)
    field(:v, :integer)
    field(:value, :wei)
    field(:from_address_hash, :address_hash)
    field(:to_address_hash, :address_hash)
    field(:created_contract_address_hash, :address_hash)
  end

  @desc """
  Represents a token transfer between addresses.
  """
  object :token_transfer do
    field(:amount, :decimal)
    field(:from_address_hash, :address_hash)
    field(:to_address_hash, :address_hash)
    field(:token_contract_address_hash, :address_hash)
    field(:transaction_hash, :full_hash)
  end
end
