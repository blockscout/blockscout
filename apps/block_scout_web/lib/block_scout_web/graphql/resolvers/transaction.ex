# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.GraphQL.Resolvers.Transaction do
  @moduledoc false

  import Absinthe.Resolution.Helpers, only: [on_load: 2]

  alias Absinthe.Relay.Connection
  alias Explorer.Chain.{Address, TokenTransfer}
  alias Explorer.Chain.Transaction, as: ChainTransaction
  alias Explorer.{GraphQL, Repo}

  # EIP-2718 type of the EIP-8430 transaction: `0x79`.
  @eip_8430_transaction_type 0x79

  def get_by(_, %{hash: hash}, _),
    do: GraphQL.get_transaction_by_hash(hash)

  def get_by(%Address{hash: address_hash}, args, _) do
    connection_args = Map.take(args, [:after, :before, :first, :last])

    replica = Repo.replica()

    address_hash
    |> GraphQL.address_to_transactions_query(args.order)
    |> Connection.from_query(&replica.all/1, connection_args, options(args))
  end

  def get_by(%TokenTransfer{transaction_hash: hash}, _, _),
    do: GraphQL.get_transaction_by_hash(hash)

  @doc """
  Resolves the `r`, `s` and `v` fields of a transaction.

  An EIP-8430 transaction (EIP-2718 type `0x79`) has no such fields. The
  database contains zero compatibility values for it, so the resolver returns
  `nil` by the type of the transaction.
  """
  @spec signature_field(ChainTransaction.t(), map(), Absinthe.Resolution.t()) :: {:ok, Decimal.t() | nil}
  def signature_field(%ChainTransaction{type: @eip_8430_transaction_type}, _args, _resolution), do: {:ok, nil}

  def signature_field(%ChainTransaction{} = transaction, _args, %{definition: %{schema_node: %{identifier: field}}}) do
    {:ok, Map.get(transaction, field)}
  end

  @doc """
  Resolves a field from the row of the transaction in `eip_8430_transactions`.
  The name of the GraphQL field is the name of the field of the row.

  The resolver first reads the type of the transaction. For a transaction that
  is not an EIP-8430 transaction (EIP-2718 type `0x79`), it returns `nil` and
  loads nothing. For an EIP-8430 transaction, it loads the row through
  Dataloader, so one query serves all transactions of the response.
  """
  @spec eip_8430_field(ChainTransaction.t(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:middleware, module(), term()}
  def eip_8430_field(
        %ChainTransaction{type: @eip_8430_transaction_type} = transaction,
        _args,
        %{context: %{loader: loader}, definition: %{schema_node: %{identifier: field}}}
      ) do
    loader
    |> Dataloader.load(:db, :eip_8430_transaction, transaction)
    |> on_load(fn loader ->
      case Dataloader.get(loader, :db, :eip_8430_transaction, transaction) do
        nil -> {:ok, nil}
        eip_8430_transaction -> {:ok, Map.get(eip_8430_transaction, field)}
      end
    end)
  end

  def eip_8430_field(_transaction, _args, _resolution), do: {:ok, nil}

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
