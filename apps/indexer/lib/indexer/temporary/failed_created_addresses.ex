defmodule Indexer.Temporary.FailedCreatedAddresses do
  @moduledoc """
  Temporary module to fix internal transactions and their created transactions if a parent transaction has failed.
  """

  use GenServer

  import Ecto.Query

  alias Explorer.Chain.{InternalTransaction, Transaction}
  alias Explorer.Repo
  alias Indexer.Temporary.FailedCreatedAddresses.TaskSupervisor

  @task_options [max_concurrency: 3, timeout: 15_000]

  def start_link([json_rpc_named_arguments, gen_server_options]) do
    GenServer.start_link(__MODULE__, json_rpc_named_arguments, gen_server_options)
  end

  @impl GenServer
  def init(json_rpc_named_arguments) do
    run(json_rpc_named_arguments)

    {:ok, json_rpc_named_arguments}
  end

  def run(json_rpc_named_arguments) do
    query =
      from(it in InternalTransaction,
        left_join: t in Transaction,
        on: it.transaction_hash == t.hash,
        where: t.status == ^0 and not is_nil(it.created_contract_address_hash),
        preload: :transaction
      )

    found_internal_transactions = Repo.all(query)

    TaskSupervisor
    |> Task.Supervisor.async_stream(
      found_internal_transactions,
      fn internal_transaction -> fix_internal_transaction(internal_transaction, json_rpc_named_arguments) end,
      @task_options
    )
    |> Enum.to_list()
  end

  def fix_internal_transaction(internal_transaction, json_rpc_named_arguments) do
    internal_transaction
    |> code_entry()
    |> Indexer.Code.Fetcher.run(json_rpc_named_arguments)

    internal_transaction.transaction
    |> transaction_entry()
    |> Indexer.InternalTransaction.Fetcher.run(json_rpc_named_arguments)
  end

  def code_entry(%InternalTransaction{
        block_number: block_number,
        created_contract_address_hash: %{bytes: created_contract_bytes}
      }) do
    [{block_number, created_contract_bytes, <<>>}]
  end

  def transaction_entry(%Transaction{hash: %{bytes: bytes}, index: index, block_number: block_number}) do
    [{block_number, bytes, index}]
  end
end
