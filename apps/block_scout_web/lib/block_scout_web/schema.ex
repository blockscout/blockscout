defmodule BlockScoutWeb.Schema do
  @moduledoc false

  use Absinthe.Schema
  use Absinthe.Relay.Schema, :modern

  alias Absinthe.Middleware.Dataloader, as: AbsintheMiddlewareDataloader
  alias Absinthe.Plugin, as: AbsinthePlugin

  alias BlockScoutWeb.Resolvers.{
    Address,
    Block,
    CeloAccount,
    CeloGoldTransfer,
    CeloParameters,
    CeloTransfer,
    CeloTransferTx,
    CeloUtil,
    CeloValidator,
    CeloValidatorGroup,
    CoinBalances,
    Competitor,
    InternalTransaction,
    TokenTransfer,
    Transaction
  }

  alias Explorer.Chain
  alias Explorer.Chain.InternalTransaction, as: ExplorerChainInternalTransaction
  alias Explorer.Chain.TokenTransfer, as: ExplorerChainTokenTransfer
  alias Explorer.Chain.Transaction, as: ExplorerChainTransaction

  import_types(BlockScoutWeb.Schema.Types)

  @complexity_multiplier 5

  node interface do
    resolve_type(fn
      %ExplorerChainInternalTransaction{}, _ ->
        :internal_transaction

      %ExplorerChainTokenTransfer{}, _ ->
        :token_transfer

      %ExplorerChainTransaction{}, _ ->
        :transaction

      _, _ ->
        nil
    end)
  end

  query do
    node field do
      resolve(fn
        %{type: :internal_transaction, id: id}, _ ->
          %{"transaction_hash" => transaction_hash_string, "index" => index} = Jason.decode!(id)
          {:ok, transaction_hash} = Chain.string_to_transaction_hash(transaction_hash_string)
          InternalTransaction.get_by(%{transaction_hash: transaction_hash, index: index})

        %{type: :token_transfer, id: id}, _ ->
          %{"transaction_hash" => transaction_hash_string, "log_index" => log_index} = Jason.decode!(id)
          {:ok, transaction_hash} = Chain.string_to_transaction_hash(transaction_hash_string)
          TokenTransfer.get_by(%{transaction_hash: transaction_hash, log_index: log_index})

        %{type: :transaction, id: transaction_hash_string}, _ ->
          {:ok, hash} = Chain.string_to_transaction_hash(transaction_hash_string)
          Transaction.get_by(%{}, %{hash: hash}, %{})

        _, _ ->
          {:error, "Unknown node"}
      end)
    end

    @desc "Gets an address by hash."
    field :address, :address do
      arg(:hash, non_null(:address_hash))
      resolve(&Address.get_by/3)
      complexity(fn %{hash: _hash}, child_complexity -> @complexity_multiplier * child_complexity end)
    end

    @desc "Gets the leaderboard"
    field :leaderboard, list_of(:competitor) do
      resolve(&Competitor.get_by/3)
    end

    @desc "Gets an account by address hash."
    field :celo_account, :celo_account do
      arg(:hash, non_null(:address_hash))
      resolve(&CeloAccount.get_by/3)
      complexity(fn %{hash: _hash}, child_complexity -> @complexity_multiplier * child_complexity end)
    end

    @desc "Gets all the claims given a address hash."
    field :celo_claims, list_of(:celo_claims) do
      arg(:hash, non_null(:address_hash))
      arg(:limit, :integer, default_value: 20)
      resolve(&CeloAccount.get_claims/3)
      complexity(fn %{limit: limit}, child_complexity -> limit * child_complexity end)
    end

    @desc "Gets a validator by address hash."
    field :celo_validator, :celo_validator do
      arg(:hash, non_null(:address_hash))
      resolve(&CeloValidator.get_by/3)
      complexity(fn %{hash: _hash}, child_complexity -> @complexity_multiplier * child_complexity end)
    end

    @desc "Gets a validator group by address hash."
    field :celo_validator_group, :celo_validator_group do
      arg(:hash, non_null(:address_hash))
      resolve(&CeloValidatorGroup.get_by/3)
      complexity(fn %{hash: _hash}, child_complexity -> @complexity_multiplier * child_complexity end)
    end

    @desc "Gets all validator groups."
    field :celo_validator_groups, list_of(:celo_validator_group) do
      resolve(&CeloValidatorGroup.get_by/3)
    end

    @desc "Gets Celo network parameters"
    field :celo_parameters, :celo_parameters do
      resolve(&CeloParameters.get_by/3)
    end

    @desc "Gets addresses by address hash."
    field :addresses, list_of(:address) do
      arg(:hashes, non_null(list_of(non_null(:address_hash))))
      resolve(&Address.get_by/3)
      complexity(fn %{hashes: hashes}, child_complexity -> length(hashes) * child_complexity end)
    end

    @desc "Gets a block by number."
    field :block, :block do
      arg(:number, non_null(:integer))
      resolve(&Block.get_by/3)
      complexity(fn %{number: _number}, child_complexity -> @complexity_multiplier * child_complexity end)
    end

    @desc "Gets latest block number."
    field :latest_block, :integer do
      resolve(&CeloUtil.get_latest_block/3)
    end

    @desc "Gets token transfers by token contract address hash."
    connection field(:token_transfers, node_type: :token_transfer) do
      arg(:token_contract_address_hash, non_null(:address_hash))
      arg(:count, :integer)

      resolve(&TokenTransfer.get_by/3)

      complexity(fn
        %{first: first}, child_complexity ->
          first * child_complexity

        %{last: last}, child_complexity ->
          last * child_complexity
      end)
    end

    @desc "Gets Gold token transfers."
    connection field(:gold_transfers, node_type: :gold_transfer) do
      arg(:address_hash, :address_hash)
      arg(:count, :integer)

      resolve(&CeloGoldTransfer.get_by/3)

      complexity(fn
        %{first: first}, child_complexity ->
          first * child_complexity

        %{last: last}, child_complexity ->
          last * child_complexity
      end)
    end

    @desc "Gets Gold and stable token transfer transactions."
    connection field(:transfer_txs, node_type: :transfer_tx) do
      arg(:address_hash, :address_hash)
      arg(:count, :integer)

      resolve(&CeloTransferTx.get_by/3)

      complexity(fn
        %{first: first}, child_complexity ->
          first * child_complexity

        %{last: last}, child_complexity ->
          last * child_complexity
      end)
    end

    @desc "Gets Gold and stable token transfers."
    connection field(:celo_transfers, node_type: :celo_transfer) do
      arg(:address_hash, :address_hash)
      arg(:count, :integer)

      resolve(&CeloTransfer.get_by/3)

      complexity(fn
        %{first: first}, child_complexity ->
          first * child_complexity

        %{last: last}, child_complexity ->
          last * child_complexity
      end)
    end

    @desc "Gets coin balances by address hash"
    connection field(:coin_balances, node_type: :coin_balance) do
      arg(:address, non_null(:address_hash))
      arg(:count, :integer)
      resolve(&CoinBalances.get_by/3)
    end

    @desc "Gets a transaction by hash."
    field :transaction, :transaction do
      arg(:hash, non_null(:full_hash))
      resolve(&Transaction.get_by/3)
      complexity(fn %{hash: _hash}, child_complexity -> @complexity_multiplier * child_complexity end)
    end
  end

  subscription do
    field :token_transfers, list_of(:token_transfer) do
      arg(:token_contract_address_hash, non_null(:address_hash))

      config(fn args, _info ->
        {:ok, topic: to_string(args.token_contract_address_hash)}
      end)
    end
  end

  def context(context) do
    loader = Dataloader.add_source(Dataloader.new(), :db, Chain.data())

    Map.put(context, :loader, loader)
  end

  def plugins do
    [AbsintheMiddlewareDataloader] ++ AbsinthePlugin.defaults()
  end
end
