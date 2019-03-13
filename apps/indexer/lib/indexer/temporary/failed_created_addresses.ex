defmodule Indexer.Temporary.FailedCreatedAddresses do
  @moduledoc """
  Temporary module to fix internal transactions and their created transactions if a parent transaction has failed.
  """
  use GenServer

  require Logger

  import Ecto.Query

  alias Explorer.Chain.{InternalTransaction, Transaction}
  alias Explorer.Repo
  alias Indexer.Temporary.FailedCreatedAddresses.TaskSupervisor

  @task_options [max_concurrency: 3, timeout: :infinity]
  @query_timeout :infinity

  def start_link([json_rpc_named_arguments, gen_server_options]) do
    GenServer.start_link(__MODULE__, json_rpc_named_arguments, gen_server_options)
  end

  @impl GenServer
  def init(json_rpc_named_arguments) do
    schedule_work()

    {:ok, json_rpc_named_arguments}
  end

  def schedule_work do
    Process.send_after(self(), :run, 1_000)
  end

  @impl GenServer
  def handle_info(:run, json_rpc_named_arguments) do
    run(json_rpc_named_arguments)

    {:noreply, json_rpc_named_arguments}
  end

  def run(json_rpc_named_arguments) do
    Logger.debug(
      [
        "Started query to fetch internal transactions that need to be fixed"
      ],
      fetcher: :failed_created_addresses
    )

    query =
      from(t in Transaction,
        left_join: it in InternalTransaction,
        on: it.transaction_hash == t.hash,
        where: t.status == ^0 and not is_nil(it.created_contract_address_hash),
        distinct: t.hash
      )

    found_transactions = Repo.all(query, timeout: @query_timeout)

    Logger.debug(
      [
        "Finished query to fetch internal transactions that need to be fixed. Number of records is #{
          Enum.count(found_transactions)
        }"
      ],
      fetcher: :failed_created_addresses
    )

    TaskSupervisor
    |> Task.Supervisor.async_stream_nolink(
      found_transactions,
      fn transaction -> fix_internal_transaction(transaction, json_rpc_named_arguments) end,
      @task_options
    )
    |> Enum.to_list()
  end

  def fix_internal_transaction(transaction, json_rpc_named_arguments) do
    # credo:disable-for-next-line
    try do
      Logger.debug(
        [
          "Started fixing transaction #{to_string(transaction.hash)}"
        ],
        fetcher: :failed_created_addresses
      )

      transaction_with_internal_transactions = Repo.preload(transaction, [:internal_transactions])

      transaction_with_internal_transactions.internal_transactions
      |> Enum.filter(fn internal_transaction ->
        internal_transaction.created_contract_address_hash
      end)
      |> Enum.each(fn internal_transaction ->
        :ok =
          internal_transaction
          |> code_entry()
          |> Indexer.Code.Fetcher.run(json_rpc_named_arguments)
      end)

      :ok =
        transaction
        |> transaction_entry()
        |> Indexer.InternalTransaction.Fetcher.run(json_rpc_named_arguments)

      Logger.debug(
        [
          "Finished fixing transaction #{to_string(transaction.hash)}"
        ],
        fetcher: :failed_created_addresses
      )
    rescue
      e ->
        Logger.debug(
          [
            "Failed fixing transaction #{to_string(transaction.hash)} because of #{inspect(e)}"
          ],
          fetcher: :failed_created_addresses
        )
    end
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
