defmodule BlockScoutWeb.Schema do
  @moduledoc false

  use Absinthe.Schema
  use Absinthe.Relay.Schema, :modern

  alias Absinthe.Middleware.Dataloader, as: AbsintheMiddlewareDataloader
  alias Absinthe.Plugin, as: AbsinthePlugin

  alias BlockScoutWeb.Resolvers.{
    Address,
    Block,
    InternalTransaction,
    Transaction
  }

  alias Explorer.Chain
  alias Explorer.Chain.InternalTransaction, as: ExplorerChainInternalTransaction
  alias Explorer.Chain.Transaction, as: ExplorerChainTransaction

  import_types(BlockScoutWeb.Schema.Types)

  node interface do
    resolve_type(fn
      %ExplorerChainTransaction{}, _ ->
        :transaction

      %ExplorerChainInternalTransaction{}, _ ->
        :internal_transaction

      _, _ ->
        nil
    end)
  end

  query do
    node field do
      resolve(fn
        %{type: :transaction, id: transaction_hash_string}, _ ->
          {:ok, hash} = Chain.string_to_transaction_hash(transaction_hash_string)
          Transaction.get_by(%{}, %{hash: hash}, %{})

        %{type: :internal_transaction, id: id}, _ ->
          %{"transaction_hash" => transaction_hash_string, "index" => index} = Jason.decode!(id)
          {:ok, transaction_hash} = Chain.string_to_transaction_hash(transaction_hash_string)
          InternalTransaction.get_by(%{transaction_hash: transaction_hash, index: index})

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

    @desc "Gets a transaction by hash."
    field :transaction, :transaction do
      arg(:hash, non_null(:full_hash))
      resolve(&Transaction.get_by/3)
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
