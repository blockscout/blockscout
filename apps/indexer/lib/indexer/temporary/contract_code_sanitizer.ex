defmodule Indexer.Temporary.ContractCodeSanitizer do
  @moduledoc """
  Finds internal transactions with not empty created_contract_address_hash
  and empty created_contract_address_hash in parent transaction
  and set consensus=false for blocks containing these internal transactions.
  """

  use GenServer

  import Ecto.Query

  require Logger

  alias Explorer.Chain.{Import.Runner.Blocks, InternalTransaction}
  alias Explorer.Repo

  @interval :timer.seconds(1)
  @batch_size 100

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(_args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(_) do
    Logger.metadata(fetcher: :contract_code_sanitizer)
    Process.send_after(self(), :update_batch, @interval)
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:update_batch, state) do
    case update_batch() do
      [] ->
        {:stop, :normal, state}

      _ ->
        Process.send_after(self(), :update_batch, @interval)
        {:noreply, state}
    end
  end

  def update_batch do
    query =
      from(
        internal_transaction in InternalTransaction,
        join: transaction in assoc(internal_transaction, :transaction),
        join: block in assoc(internal_transaction, :block),
        where: not is_nil(internal_transaction.created_contract_address_hash),
        where: is_nil(transaction.created_contract_address_hash),
        where: block.consensus,
        limit: @batch_size,
        select: {block.number, transaction.hash, internal_transaction.index}
      )

    case Repo.all(query, timeout: :infinity) do
      [] ->
        Logger.info("ContractCodeSanitizer finished its work")
        []

      transactions ->
        Logger.info(
          "Missing contract creations found ({block_number, transaction_hash, internal_transaction_index}): #{transactions |> Enum.map(fn {number, hash, index} -> {number, to_string(hash), index} end) |> inspect()}"
        )

        transactions
        |> Enum.map(fn {block_number, _, _} -> block_number end)
        |> Enum.uniq()
        |> Blocks.invalidate_consensus_blocks()

        transactions
    end
  end
end
