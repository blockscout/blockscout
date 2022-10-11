defmodule BlockScoutWeb.Schema.Types do
  @moduledoc false

  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  import Absinthe.Resolution.Helpers

  alias BlockScoutWeb.Resolvers.{
    Address,
    CeloAccount,
    CeloClaim,
    CeloTransfer,
    CeloValidator,
    CeloValidatorGroup,
    InternalTransaction,
    TokenTransfer,
    Transaction
  }

  import_types(Absinthe.Type.Custom)
  import_types(BlockScoutWeb.Schema.Scalars)

  connection(node_type: :celo_account)
  connection(node_type: :celo_claims)
  connection(node_type: :celo_validator)
  connection(node_type: :celo_validator_group)
  connection(node_type: :competitor)
  connection(node_type: :address)
  connection(node_type: :transaction)
  connection(node_type: :internal_transaction)
  connection(node_type: :token_transfer)
  connection(node_type: :gold_transfer)
  connection(node_type: :coin_balance)
  connection(node_type: :transfer_tx)
  connection(node_type: :celo_transfer)

  @desc """
  A stored representation of a Web3 address.
  """
  object :address do
    field(:hash, :address_hash)
    field(:fetched_coin_balance, :wei)
    field(:fetched_coin_balance_block_number, :integer)
    field(:contract_code, :data)
    field(:online, :boolean)

    field :smart_contract, :smart_contract do
      resolve(dataloader(:db, :smart_contract))
    end

    field(:celo_account, :celo_account) do
      resolve(&CeloAccount.get_by/3)
    end

    field(:celo_validator, :celo_validator) do
      resolve(&CeloValidator.get_by/3)
    end

    field(:celo_validator_group, :celo_validator_group) do
      resolve(&CeloValidatorGroup.get_by/3)
    end

    connection field(:transactions, node_type: :transaction) do
      arg(:count, :integer)
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
  Celo account information
  """
  object :celo_account do
    field(:address, :address_hash)
    field(:account_type, :string)
    field(:nonvoting_locked_gold, :wei)
    field(:locked_gold, :wei)
    field(:active_gold, :wei)
    field(:votes, :wei)

    field(:usd, :wei)

    field(:attestations_requested, :integer)
    field(:attestations_fulfilled, :integer)
    field(:name, :string)
    field(:url, :string)

    field(:address_info, :address) do
      resolve(&Address.get_by/3)
    end

    field(:validator, :celo_validator) do
      resolve(&CeloValidator.get_by/3)
    end

    field(:group, :celo_validator_group) do
      resolve(&CeloValidatorGroup.get_by/3)
    end

    connection field(:claims, node_type: :celo_claims) do
      resolve(&CeloClaim.get_by/3)
    end

    connection field(:voted, node_type: :celo_validator_group) do
      resolve(&CeloAccount.get_voted/3)
    end
  end

  @desc """
  Celo validator information
  """
  object :celo_validator do
    field(:address, :address_hash)
    field(:group_address_hash, :address_hash)
    field(:signer_address_hash, :address_hash)
    field(:member, :integer)
    field(:score, :wei)
    field(:last_elected, :integer)
    field(:last_online, :integer)

    field(:nonvoting_locked_gold, :wei)
    field(:locked_gold, :wei)
    field(:usd, :wei)
    field(:name, :string)
    field(:url, :string)
    field(:active_gold, :wei)

    field(:attestations_requested, :integer)
    field(:attestations_fulfilled, :integer)

    field(:address_info, :address) do
      resolve(&Address.get_by/3)
    end

    field(:account, :celo_account) do
      resolve(&CeloAccount.get_by/3)
    end

    field(:group_info, :celo_validator_group) do
      resolve(&CeloValidatorGroup.get_by/3)
    end
  end

  @desc """
  Celo validator group information
  """
  object :celo_validator_group do
    field(:address, :address_hash)
    field(:commission, :wei)
    field(:votes, :wei)
    field(:num_members, :integer)

    field(:nonvoting_locked_gold, :wei)
    field(:locked_gold, :wei)
    field(:usd, :wei)
    field(:name, :string)
    field(:url, :string)
    field(:active_gold, :wei)

    field(:rewards_ratio, :wei)
    field(:accumulated_rewards, :wei)
    field(:accumulated_active, :wei)
    field(:receivable_votes, :decimal)

    field(:address_info, :address) do
      resolve(&Address.get_by/3)
    end

    field(:account, :celo_account) do
      resolve(&CeloAccount.get_by/3)
    end

    connection field(:affiliates, node_type: :celo_validator) do
      resolve(&CeloValidator.get_by/3)
    end

    connection field(:voters, node_type: :celo_account) do
      resolve(&CeloValidatorGroup.get_voters/3)
    end
  end

  @desc """
  Celo stable coins
  """
  object :celo_stable_coins do
    field(:cusd, :address_hash)
    field(:ceur, :address_hash)
    field(:creal, :address_hash)
  end

  @desc """
  Celo network parameters
  """
  object :celo_parameters do
    field(:total_locked_gold, :wei)
    field(:num_registered_validators, :integer)
    field(:min_electable_validators, :integer)
    field(:max_electable_validators, :integer)
    field(:gold_token, :address_hash, deprecate: "Use celoToken instead.")
    field(:stable_token, :address_hash, deprecate: "Use stableTokens instead.")
    field(:celo_token, :address_hash)
    field(:stable_tokens, :celo_stable_coins)
  end

  @desc """
  Celo Claims
  """
  object :celo_claims do
    field(:address, :address_hash)
    field(:type, :string)
    field(:element, :string)
    field(:verified, :boolean)
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
  Leaderboard entry
  """
  object :competitor do
    field(:address, :address_hash)
    field(:points, :float)
    field(:identity, :string)
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
    field(:block_number, :integer)
    field(:log_index, :integer)
    field(:token_id, :decimal)
    field(:from_address_hash, :address_hash)
    field(:to_address_hash, :address_hash)
    field(:token_contract_address_hash, :address_hash)
    field(:transaction_hash, :full_hash)
    field(:block_hash, :full_hash)
    field(:comment, :string)
  end

  @desc """
  Represents a CELO token transfer between addresses.
  """
  node object(:gold_transfer, id_fetcher: &gold_transfer_id_fetcher/2) do
    field(:value, :decimal)
    field(:block_number, :integer)
    field(:from_address_hash, :address_hash)
    field(:to_address_hash, :address_hash)
    field(:transaction_hash, :full_hash)
    field(:comment, :string)
  end

  @desc """
  Represents a CELO or usd token transfer between addresses.
  """
  node object(:celo_transfer, id_fetcher: &celo_transfer_id_fetcher/2) do
    field(:value, :decimal)
    field(:token, :string)
    field(:token_address, :string)
    field(:token_type, :string)
    field(:token_id, :decimal)
    field(:block_number, :integer)
    field(:from_address_hash, :address_hash)
    field(:to_address_hash, :address_hash)
    field(:transaction_hash, :full_hash)

    field(:log_index, :integer)

    field(:gas_price, :wei)
    field(:gas_used, :decimal)
    field(:input, :string)
    field(:timestamp, :datetime)
    field(:comment, :string)

    field(:to_account_hash, :address_hash)
    field(:from_account_hash, :address_hash)
  end

  @desc """
  Represents a CELO token transfer between addresses.
  """
  node object(:transfer_tx, id_fetcher: &transfer_tx_id_fetcher/2) do
    field(:gateway_fee_recipient, :address_hash)
    field(:gateway_fee, :address_hash)
    field(:fee_currency, :address_hash)
    field(:fee_token, :string)
    field(:address_hash, :address_hash)
    field(:transaction_hash, :full_hash)
    field(:block_number, :integer)
    field(:gas_price, :wei)
    field(:gas_used, :decimal)
    field(:input, :string)
    field(:timestamp, :datetime)

    connection field(:celo_transfer, node_type: :celo_transfer) do
      arg(:count, :integer)
      resolve(&CeloTransfer.get_by/3)

      complexity(fn
        %{first: first}, child_complexity ->
          first * child_complexity

        %{last: last}, child_complexity ->
          last * child_complexity
      end)
    end

    connection field(:token_transfer, node_type: :celo_transfer) do
      arg(:count, :integer)
      resolve(&TokenTransfer.get_by/3)

      complexity(fn
        %{first: first}, child_complexity ->
          first * child_complexity

        %{last: last}, child_complexity ->
          last * child_complexity
      end)
    end
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

  @desc """
  Coin balance record
  """
  node object(:coin_balance, id_fetcher: &coin_balance_id_fetcher/2) do
    field(:block_number, :integer)
    field(:value, :wei)
    field(:delta, :wei)
    field(:block_timestamp, :datetime)
  end

  def token_transfer_id_fetcher(%{transaction_hash: transaction_hash, log_index: log_index}, _) do
    Jason.encode!(%{transaction_hash: to_string(transaction_hash), log_index: log_index})
  end

  def gold_transfer_id_fetcher(
        %{transaction_hash: transaction_hash, log_index: log_index, tx_index: tx_index, index: index},
        _
      ) do
    Jason.encode!(%{
      transaction_hash: to_string(transaction_hash),
      log_index: log_index,
      tx_index: tx_index,
      index: index
    })
  end

  def celo_transfer_id_fetcher(
        %{transaction_hash: transaction_hash, log_index: log_index},
        _
      ) do
    Jason.encode!(%{
      transaction_hash: to_string(transaction_hash),
      log_index: log_index
    })
  end

  def coin_balance_id_fetcher(%{address_hash: address_hash, block_number: block_number}, _) do
    Jason.encode!(%{address_hash: to_string(address_hash), block_number: block_number})
  end

  def transaction_id_fetcher(%{hash: hash}, _), do: to_string(hash)

  def internal_transaction_id_fetcher(%{transaction_hash: transaction_hash, index: index}, _) do
    Jason.encode!(%{transaction_hash: to_string(transaction_hash), index: index})
  end

  def transfer_tx_id_fetcher(%{transaction_hash: transaction_hash, address_hash: address_hash}, _) do
    Jason.encode!(%{transaction_hash: to_string(transaction_hash), address_hash: to_string(address_hash)})
  end
end
