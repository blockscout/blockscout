defmodule BlockScoutWeb.GraphQL.Schema.Transaction do
  @moduledoc false
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias BlockScoutWeb.GraphQL.Resolvers.{Block, InternalTransaction}

  case @chain_type do
    :celo ->
      @chain_type_fields quote(
                           do: [
                             field(:gas_token_contract_address_hash, :address_hash)
                           ]
                         )

    _ ->
      @chain_type_fields quote(do: [])
  end

  defmacro generate do
    quote do
      node object(:transaction, id_fetcher: &transaction_id_fetcher/2) do
        field(:cumulative_gas_used, :decimal)
        field(:error, :string)
        field(:gas, :decimal)
        field(:gas_price, :wei)
        field(:gas_used, :decimal)
        field(:hash, :full_hash)
        field(:index, :integer)
        field(:input, :string)
        field(:nonce, :nonce_hash)
        field(:r, :decimal)
        field(:s, :decimal)
        field(:status, :status)
        field(:v, :decimal)
        field(:value, :wei)
        field(:block_hash, :full_hash)
        field(:block_number, :integer)
        field(:from_address_hash, :address_hash)
        field(:to_address_hash, :address_hash)
        field(:created_contract_address_hash, :address_hash)
        field(:earliest_processing_start, :datetime)
        field(:revert_reason, :string)
        field(:max_priority_fee_per_gas, :wei)
        field(:max_fee_per_gas, :wei)
        field(:type, :integer)
        field(:has_error_in_internal_transactions, :boolean)

        field :block, :block do
          resolve(&Block.get_by/3)
        end

        connection field(:internal_transactions, node_type: :internal_transaction) do
          arg(:count, :integer)
          resolve(&InternalTransaction.get_by/3)

          complexity(fn params, child_complexity -> process_complexity(params, child_complexity) end)
        end

        unquote_splicing(@chain_type_fields)
      end
    end
  end
end

defmodule BlockScoutWeb.GraphQL.Schema.SmartContracts do
  @moduledoc false
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  case @chain_type do
    :zksync ->
      @chain_type_fields quote(
                           do: [
                             field(:optimization_runs, :string),
                             field(:zk_compiler_version, :string)
                           ]
                         )

    _ ->
      @chain_type_fields quote(do: [field(:optimization_runs, :integer)])
  end

  defmacro generate do
    quote do
      object :smart_contract do
        field(:name, :string)
        field(:compiler_version, :string)
        field(:optimization, :boolean)
        field(:contract_source_code, :string)
        field(:abi, :json)
        field(:address_hash, :address_hash)
        field(:constructor_arguments, :string)
        field(:evm_version, :string)
        field(:external_libraries, :json)
        field(:verified_via_sourcify, :boolean)
        field(:partially_verified, :boolean)
        field(:file_path, :string)
        field(:is_changed_bytecode, :boolean)
        field(:compiler_settings, :json)
        field(:verified_via_eth_bytecode_db, :boolean)
        field(:language, :language)

        unquote_splicing(@chain_type_fields)
      end
    end
  end
end

defmodule BlockScoutWeb.GraphQL.Schema.Types do
  @moduledoc false
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  require BlockScoutWeb.GraphQL.Schema.{Transaction, SmartContracts}

  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  import Absinthe.Resolution.Helpers

  alias BlockScoutWeb.GraphQL.Resolvers.{
    Token,
    TokenTransfer,
    Transaction
  }

  alias BlockScoutWeb.GraphQL.Schema.SmartContracts, as: SmartContractsSchema
  alias BlockScoutWeb.GraphQL.Schema.Transaction, as: TransactionSchema

  # TODO: leverage `Ecto.Enum.values(SmartContract, :language)` to deduplicate
  # language definitions
  @default_languages ~w(solidity vyper yul)a

  case @chain_type do
    :arbitrum ->
      @chain_type_languages ~w(stylus_rust)a

    :zilliqa ->
      @chain_type_languages ~w(scilla)a

    _ ->
      @chain_type_languages ~w()a
  end

  enum(:language, values: @default_languages ++ @chain_type_languages)

  import_types(Absinthe.Type.Custom)
  import_types(BlockScoutWeb.GraphQL.Schema.Scalars)

  connection(node_type: :transaction)
  connection(node_type: :internal_transaction)
  connection(node_type: :token_transfer)

  @desc """
  A stored representation of a Web3 address.
  """
  object :address do
    field(:fetched_coin_balance, :wei)
    field(:fetched_coin_balance_block_number, :integer)
    field(:hash, :address_hash)
    field(:contract_code, :data)
    field(:nonce, :integer)
    field(:gas_used, :integer)
    field(:transactions_count, :integer)
    field(:token_transfers_count, :integer)

    field :smart_contract, :smart_contract do
      resolve(dataloader(:db, :smart_contract))
    end

    connection field(:transactions, node_type: :transaction) do
      arg(:count, :integer)
      arg(:order, type: :sort_order, default_value: :desc)
      resolve(&Transaction.get_by/3)

      complexity(fn params, child_complexity -> process_complexity(params, child_complexity) end)
    end

    connection field(:token_transfers, node_type: :token_transfer) do
      arg(:count, :integer)
      resolve(&TokenTransfer.get_by/3)

      complexity(fn params, child_complexity -> process_complexity(params, child_complexity) end)
    end
  end

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
    field(:hash, :full_hash)
    field(:miner_hash, :address_hash)
    field(:nonce, :nonce_hash)
    field(:number, :integer)
    field(:parent_hash, :full_hash)
    field(:size, :integer)
    field(:timestamp, :datetime)
    field(:total_difficulty, :decimal)
    field(:base_fee_per_gas, :wei)
    field(:is_empty, :boolean)
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
    field(:created_contract_address_hash, :address_hash)
    field(:from_address_hash, :address_hash)
    field(:to_address_hash, :address_hash)
    field(:transaction_hash, :full_hash)
    field(:block_number, :integer)
    field(:transaction_index, :integer)
    field(:block_hash, :full_hash)
    field(:block_index, :integer)
  end

  @desc """
  The representation of a verified Smart Contract.

  "A contract in the sense of Solidity is a collection of code (its functions)
  and data (its state) that resides at a specific address on the Ethereum
  blockchain."
  http://solidity.readthedocs.io/en/v0.4.24/introduction-to-smart-contracts.html
  """
  SmartContractsSchema.generate()

  @desc """
  Represents a token transfer between addresses.
  """
  node object(:token_transfer, id_fetcher: &token_transfer_id_fetcher/2) do
    field(:amount, :decimal)
    field(:amounts, list_of(:decimal))
    field(:block_number, :integer)
    field(:log_index, :integer)
    field(:token_ids, list_of(:decimal))
    field(:from_address_hash, :address_hash)
    field(:to_address_hash, :address_hash)
    field(:token_contract_address_hash, :address_hash)
    field(:transaction_hash, :full_hash)

    field :transaction, :transaction do
      resolve(&Transaction.get_by/3)
    end

    field :token, :token do
      resolve(&Token.get_by/3)
    end
  end

  @desc """
  Represents a token.
  """
  object :token do
    field(:name, :string)
    field(:symbol, :string)
    field(:total_supply, :decimal)
    field(:decimals, :decimal)
    field(:type, :string)
    field(:holder_count, :integer)
    field(:circulating_market_cap, :decimal)
    field(:icon_url, :string)
    field(:volume_24h, :decimal)
    field(:contract_address_hash, :address_hash)
  end

  @desc """
  Models a Web3 transaction.
  """
  TransactionSchema.generate()

  def token_transfer_id_fetcher(%{transaction_hash: transaction_hash, log_index: log_index}, _) do
    Jason.encode!(%{transaction_hash: to_string(transaction_hash), log_index: log_index})
  end

  def transaction_id_fetcher(%{hash: hash}, _), do: to_string(hash)

  def internal_transaction_id_fetcher(%{transaction_hash: transaction_hash, index: index}, _) do
    Jason.encode!(%{transaction_hash: to_string(transaction_hash), index: index})
  end

  defp process_complexity(params, child_complexity) do
    case params do
      %{first: first} ->
        first * child_complexity

      %{last: last} ->
        last * child_complexity

      %{} ->
        0
    end
  end
end
