defmodule BlockScoutWeb.GraphQL.Schema do
  @moduledoc false

  use Absinthe.Schema
  use Absinthe.Relay.Schema, :modern
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias Absinthe.Middleware.Dataloader, as: AbsintheDataloaderMiddleware
  alias Absinthe.Plugin, as: AbsinthePlugin

  alias BlockScoutWeb.GraphQL.Middleware.ApiEnabled, as: ApiEnabledMiddleware

  alias BlockScoutWeb.GraphQL.Resolvers.{
    Address,
    Block,
    InternalTransaction,
    TokenTransfer,
    Transaction
  }

  alias Explorer.Chain
  alias Explorer.Chain.InternalTransaction, as: ExplorerChainInternalTransaction
  alias Explorer.Chain.TokenTransfer, as: ExplorerChainTokenTransfer
  alias Explorer.Chain.Transaction, as: ExplorerChainTransaction

  import_types(BlockScoutWeb.GraphQL.Schema.Types)

  if @chain_type == :celo do
    import_types(BlockScoutWeb.GraphQL.Celo.Schema.Types)
  end

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
        %{type: :internal_transaction, id: id}, resolution ->
          %{"transaction_hash" => transaction_hash_string, "index" => index} = Jason.decode!(id)
          {:ok, transaction_hash} = Chain.string_to_full_hash(transaction_hash_string)
          InternalTransaction.get_by(%{transaction_hash: transaction_hash, index: index}, resolution)

        %{type: :token_transfer, id: id}, resolution ->
          %{"transaction_hash" => transaction_hash_string, "log_index" => log_index} = Jason.decode!(id)
          {:ok, transaction_hash} = Chain.string_to_full_hash(transaction_hash_string)
          TokenTransfer.get_by(%{transaction_hash: transaction_hash, log_index: log_index}, resolution)

        %{type: :transaction, id: transaction_hash_string}, resolution ->
          {:ok, hash} = Chain.string_to_full_hash(transaction_hash_string)
          Transaction.get_by(%{}, %{hash: hash}, resolution)

        _, _ ->
          {:error, "Unknown node"}
      end)
    end

    @desc "Gets an address by hash."
    field :address, :address do
      arg(:hash, non_null(:address_hash))
      resolve(&Address.get_by/3)
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

    @desc "Gets a transaction by hash."
    field :transaction, :transaction do
      arg(:hash, non_null(:full_hash))
      resolve(&Transaction.get_by/3)
    end

    if @chain_type == :celo do
      require BlockScoutWeb.GraphQL.Celo.QueryFields
      alias BlockScoutWeb.GraphQL.Celo.QueryFields

      QueryFields.generate()
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
    if Application.get_env(:block_scout_web, Api.GraphQL)[:enabled] do
      loader = Dataloader.add_source(Dataloader.new(), :db, Chain.data())

      context
      |> Map.put(:loader, loader)
      |> Map.put(:api_enabled, true)
    else
      context
      |> Map.put(:api_enabled, false)
    end
  end

  def middleware(middleware, _field, _object) do
    [ApiEnabledMiddleware | middleware]
  end

  def plugins do
    [AbsintheDataloaderMiddleware] ++ AbsinthePlugin.defaults()
  end
end
