defmodule Indexer.Fetcher.EmptyBlocksSanitizer do
  @moduledoc """
  Periodically checks empty blocks starting from the head of the chain, detects for which blocks transactions should be refetched
  and lose consensus for block in order to refetch transactions.
  """

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  require Logger

  import Ecto.Query, only: [from: 2, subquery: 1, where: 3]
  import EthereumJSONRPC, only: [integer_to_quantity: 1, json_rpc: 2, request: 1]

  alias Ecto.Changeset
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Block, PendingBlockOperation, Transaction}
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Import.Runner.Blocks

  @interval :timer.seconds(10)

  defstruct interval: @interval,
            json_rpc_named_arguments: []

  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
    default = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments}
    }

    Supervisor.child_spec(default, [])
  end

  def start_link(init_opts, gen_server_opts \\ []) do
    GenServer.start_link(__MODULE__, init_opts, gen_server_opts)
  end

  @impl GenServer
  def init(opts) when is_list(opts) do
    interval = Application.get_env(:indexer, __MODULE__)[:interval]

    state = %__MODULE__{
      json_rpc_named_arguments: Keyword.fetch!(opts, :json_rpc_named_arguments),
      interval: interval || @interval
    }

    Process.send_after(self(), :sanitize_empty_blocks, state.interval)

    {:ok, state}
  end

  @impl GenServer
  def handle_info(
        :sanitize_empty_blocks,
        %{interval: interval, json_rpc_named_arguments: json_rpc_named_arguments} = state
      ) do
    Logger.info("Start sanitizing of empty blocks. Batch size is #{limit()}",
      fetcher: :empty_blocks_to_refetch
    )

    sanitize_empty_blocks(json_rpc_named_arguments)

    Process.send_after(self(), :sanitize_empty_blocks, interval)

    {:noreply, state}
  end

  defp sanitize_empty_blocks(json_rpc_named_arguments) do
    unprocessed_non_empty_blocks_query = unprocessed_non_empty_blocks_query(limit())

    Repo.update_all(
      from(
        block in Block,
        where: block.hash in subquery(unprocessed_non_empty_blocks_query)
      ),
      set: [is_empty: false, updated_at: Timex.now()]
    )

    unprocessed_empty_blocks_from_db = unprocessed_empty_blocks_query_list(limit())

    unprocessed_empty_blocks_from_db
    |> Enum.with_index()
    |> Enum.each(fn {{block_number, block_hash}, ind} ->
      with {:ok, %{"transactions" => transactions}} <-
             %{id: ind, method: "eth_getBlockByNumber", params: [integer_to_quantity(block_number), false]}
             |> request()
             |> json_rpc(json_rpc_named_arguments) do
        transactions_count =
          transactions
          |> Enum.count()

        if transactions_count > 0 do
          Logger.info(
            "Block with number #{block_number} and hash #{to_string(block_hash)} is full of transactions. We should set consensus = false for it in order to refetch.",
            fetcher: :empty_blocks_to_refetch
          )

          Blocks.invalidate_consensus_blocks([block_number])
        else
          Logger.debug(
            "Block with number #{block_number} and hash #{to_string(block_hash)} is empty. We should set is_empty=true for it.",
            fetcher: :empty_blocks_to_refetch
          )

          set_is_empty_for_block(block_hash, true)
        end
      end
    end)

    Logger.info("Batch of empty blocks is sanitized",
      fetcher: :empty_blocks_to_refetch
    )
  end

  defp set_is_empty_for_block(block_hash, is_empty) do
    block = Chain.fetch_block_by_hash(block_hash)

    block_with_is_empty =
      block
      |> Changeset.change(%{is_empty: is_empty})

    Repo.update(block_with_is_empty)

    PendingBlockOperation
    |> where([po], po.block_hash == ^block_hash)
    |> Repo.delete_all()
  rescue
    postgrex_error in Postgrex.Error ->
      {:error, %{exception: postgrex_error}}
  end

  @head_offset 1000
  defp consensus_blocks_with_nil_is_empty_query(limit) do
    safe_block_number = BlockNumber.get_max() - @head_offset

    from(block in Block,
      where: is_nil(block.is_empty),
      where: block.number <= ^safe_block_number,
      where: block.consensus == true,
      order_by: [asc: block.hash],
      limit: ^limit
    )
  end

  defp unprocessed_non_empty_blocks_query(limit) do
    blocks_query = consensus_blocks_with_nil_is_empty_query(limit)

    from(q in subquery(blocks_query),
      inner_join: transaction in Transaction,
      on: q.number == transaction.block_number,
      select: q.hash,
      order_by: [asc: q.hash],
      lock: fragment("FOR NO KEY UPDATE OF ?", q)
    )
  end

  defp unprocessed_empty_blocks_query_list(limit) do
    blocks_query = consensus_blocks_with_nil_is_empty_query(limit)

    query =
      from(q in subquery(blocks_query),
        left_join: transaction in Transaction,
        on: q.number == transaction.block_number,
        where: is_nil(transaction.block_number),
        select: {q.number, q.hash},
        order_by: [asc: q.hash]
      )

    query
    |> Repo.all(timeout: :infinity)
  end

  defp limit do
    Application.get_env(:indexer, __MODULE__)[:batch_size]
  end
end
