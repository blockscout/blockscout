defmodule Indexer.Fetcher.PendingBlockOperationsSanitizer do
  @moduledoc """
  Set block_number for pending block operations that have it empty
  """

  use GenServer

  import Ecto.Query

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.PendingBlockOperation
  alias Indexer.Fetcher.InternalTransaction

  @interval :timer.seconds(1)
  @batch_size 1000
  @timeout :timer.minutes(1)

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
    cte_query = from(pbo in PendingBlockOperation, where: is_nil(pbo.block_number), limit: @batch_size)

    {_, block_numbers} =
      PendingBlockOperation
      |> with_cte("cte", as: ^cte_query, materialized: false)
      |> join(:inner, [pbo], po in "cte", on: pbo.block_hash == po.block_hash)
      |> join(:inner, [pbo, po], b in assoc(pbo, :block))
      |> select([pbo, po, b], b.number)
      |> update([pbo, po, b], set: [block_number: b.number])
      |> Repo.update_all([], timeout: @timeout)

    transactions = Enum.map(block_numbers, &Chain.get_transactions_of_block_number/1)

    InternalTransaction.async_fetch(block_numbers, transactions)

    block_numbers
  end
end
