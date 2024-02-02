defmodule BlockScoutWeb.Schema.Types do
  @moduledoc false

  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  import Absinthe.Resolution.Helpers

  alias BlockScoutWeb.Resolvers.{
    InternalTransaction,
    Transaction
  }

  import_types(Absinthe.Type.Custom)
  import_types(BlockScoutWeb.Schema.Scalars)

  connection(node_type: :transaction)
  connection(node_type: :internal_transaction)
  connection(node_type: :token_transfer)

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

    connection field(:transactions, node_type: :transaction) do
      arg(:count, :integer)
      arg(:order, type: :sort_order, default_value: :desc)
      resolve(&Transaction.get_by/3)

      complexity(fn
        %{first: first}, child_complexity ->
          first * child_complexity

        %{last: last}, child_complexity ->
          last * child_complexity

        %{}, _child_complexity ->
          0
      end)
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
  Models internal transactions.
  """
  node object(:internal_transaction, id_fetcher: &internal_transaction_id_fetcher/2) do
    field(:call_type, :call_type)
    field(:created_contract_code, :data)
    field(:error, :string)
    field(:gas, :decimal)
    field(:gas_used, :decimal)
    field(:index, :integer)
    field(:init, :data)
    field(:input, :data)
    field(:output, :data)
    field(:trace_address, :json)
    field(:type, :type)
    field(:value, :wei)
    field(:block_number, :integer)
    field(:transaction_index, :integer)
    field(:created_contract_address_hash, :address_hash)
    field(:from_address_hash, :address_hash)
    field(:to_address_hash, :address_hash)
    field(:transaction_hash, :full_hash)
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
  Represents a token transfer between addresses.
  """
  node object(:token_transfer, id_fetcher: &token_transfer_id_fetcher/2) do
    field(:amount, :decimal)
    field(:amounts, list_of(:decimal))
    field(:block_number, :integer)
    field(:log_index, :integer)
    field(:token_id, :decimal)
    field(:token_ids, list_of(:decimal))
    field(:from_address_hash, :address_hash)
    field(:to_address_hash, :address_hash)
    field(:token_contract_address_hash, :address_hash)
    field(:transaction_hash, :full_hash)
  end

  @desc """
  Models a Web3 transaction.
  """
  node object(:transaction, id_fetcher: &transaction_id_fetcher/2) do
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
    field(:v, :decimal)
    field(:value, :wei)
    field(:from_address_hash, :address_hash)
    field(:to_address_hash, :address_hash)
    field(:created_contract_address_hash, :address_hash)

    connection field(:internal_transactions, node_type: :internal_transaction) do
      arg(:count, :integer)
      resolve(&InternalTransaction.get_by/3)

      complexity(fn
        %{first: first}, child_complexity ->
          first * child_complexity

        %{last: last}, child_complexity ->
          last * child_complexity

        %{}, _child_complexity ->
          0
      end)
    end
  end

  def token_transfer_id_fetcher(%{transaction_hash: transaction_hash, log_index: log_index}, _) do
    Jason.encode!(%{transaction_hash: to_string(transaction_hash), log_index: log_index})
  end

  def transaction_id_fetcher(%{hash: hash}, _), do: to_string(hash)

  def internal_transaction_id_fetcher(%{transaction_hash: transaction_hash, index: index}, _) do
    Jason.encode!(%{transaction_hash: to_string(transaction_hash), index: index})
  end
end
