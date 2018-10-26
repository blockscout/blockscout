defmodule BlockScoutWeb.Schema.Types do
  @moduledoc false

  use Absinthe.Schema.Notation

  import_types(Absinthe.Type.Custom)
  import_types(BlockScoutWeb.Schema.Scalars)

  @desc """
  A package of data that contains zero or more transactions, the hash of the previous block ("parent"), and optionally
  other data. Because each block (except for the initial "genesis block") points to the previous block, the data
  structure that they form is called a "blockchain".
  """
  object :block do
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
end
