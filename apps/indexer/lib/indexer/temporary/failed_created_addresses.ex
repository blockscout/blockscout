defmodule Indexer.Temporary.FailedCreatedAddresses do
  @moduledoc """
  Temporary module to fix internal transactions and their created transactions if a parent transaction has failed.
  """

  import Ecto.Query

  alias Explorer.Chain.{InternalTransaction, Transaction}
  alias Explorer.Repo

  def run(json_rpc_named_arguments) do
    query =
      from(it in InternalTransaction,
        left_join: t in assoc(it, :transaction),
        where: t.error == 0 and not is_nil(it.created_contract_address_hash),
        preload: :transaction
      )

    query
    |> Repo.all()
    |> Enum.each(fn internal_transaction ->
      internal_transaction
      |> code_entry()
      |> Indexer.Code.Fetcher.run(json_rpc_named_arguments)

      internal_transaction.transaction_index
      |> transaction_entry()
      |> Indexer.InternalTransaction.Fetcher.run(json_rpc_named_arguments)
    end)
  end

  def code_entry(%InternalTransaction{
        block_number: block_number,
        created_contract_address_hash: %{bytes: created_contract_bytes}
      }) do
    [{block_number, created_contract_bytes}]
  end

  def transaction_entry(%Transaction{hash: %{bytes: bytes}, index: index, block_number: block_number}) do
    [{block_number, bytes, index}]
  end
end
