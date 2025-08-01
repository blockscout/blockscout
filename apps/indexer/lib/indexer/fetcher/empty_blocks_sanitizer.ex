defmodule Indexer.Fetcher.EmptyBlocksSanitizer do
  @moduledoc """
  Periodically checks empty blocks starting from the head of the chain, detects for which blocks transactions should be refetched
  and set refetch_needed=true for block in order to refetch transactions.
  """

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  require Logger

  import Ecto.Query
  import EthereumJSONRPC, only: [id_to_params: 1, integer_to_quantity: 1, json_rpc: 2, quantity_to_integer: 1]

  alias EthereumJSONRPC.Block.ByNumber
  alias EthereumJSONRPC.Blocks
  alias Explorer.Repo
  alias Explorer.Chain.{Block, Hash, PendingOperationsHelper, Transaction}
  alias Explorer.Chain.Cache.BlockNumber

  @update_timeout 60_000

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

    unprocessed_empty_blocks_list = unprocessed_empty_blocks_list_query(limit())

    unless Enum.empty?(unprocessed_empty_blocks_list) do
      blocks_response =
        unprocessed_empty_blocks_list
        |> Enum.map(fn {block_number, _} -> %{number: integer_to_quantity(block_number)} end)
        |> id_to_params()
        |> Blocks.requests(&ByNumber.request(&1, false, false))
        |> json_rpc(json_rpc_named_arguments)

      case blocks_response do
        {:ok, result} ->
          {non_empty_blocks, empty_blocks} = classify_blocks_from_result(result)
          process_non_empty_blocks(non_empty_blocks)
          process_empty_blocks(empty_blocks)

          Logger.info("Batch of empty blocks is sanitized",
            fetcher: :empty_blocks_to_refetch
          )

        {:error, reason} ->
          Logger.error(
            "Failed to fetch blocks batch: #{inspect(reason)}",
            fetcher: :empty_blocks_to_refetch
          )
      end
    end
  end

  defp classify_blocks_from_result(result) do
    result
    |> Enum.reduce({[], []}, fn %{id: _id, result: block}, {non_empty_blocks, empty_blocks} ->
      if Enum.empty?(block["transactions"]) do
        {non_empty_blocks, [block_fields(block) | empty_blocks]}
      else
        {[block_fields(block) | non_empty_blocks], empty_blocks}
      end
    end)
  end

  defp block_fields(block) do
    %{
      number: quantity_to_integer(block["number"]),
      hash: block["hash"],
      transactions_count: Enum.count(block["transactions"])
    }
  end

  defp process_non_empty_blocks([]),
    do:
      Logger.debug(
        "No non empty blocks found",
        fetcher: :empty_blocks_to_refetch
      )

  defp process_non_empty_blocks(non_empty_blocks) do
    log_message_base =
      Enum.reduce(non_empty_blocks, "Blocks \n", fn block, acc ->
        acc <>
          " with number #{block.number} and hash #{to_string(block.hash)} contains #{inspect(block.transactions_count)} transactions \n"
      end)

    log_message =
      log_message_base <>
        ", but those blocks are empty in Blockscout DB. Setting refetch_needed = true for it to re-fetch."

    Logger.info(
      log_message,
      fetcher: :empty_blocks_to_refetch
    )

    Block.set_refetch_needed(non_empty_blocks |> Enum.map(& &1.number))
  end

  defp process_empty_blocks([]),
    do:
      Logger.debug(
        "No empty blocks found",
        fetcher: :empty_blocks_to_refetch
      )

  defp process_empty_blocks(empty_blocks) do
    log_message =
      "Block with numbers #{inspect(empty_blocks |> Enum.map(& &1.number))} are empty. We're setting is_empty=true for them."

    Logger.debug(
      log_message,
      fetcher: :empty_blocks_to_refetch
    )

    mark_blocks_as_empty(empty_blocks |> Enum.map(& &1.hash))
  end

  @spec mark_blocks_as_empty([Hash.Full.t()]) ::
          {non_neg_integer(), nil | [term()]} | {:error, %{exception: Postgrex.Error.t()}}
  defp mark_blocks_as_empty(block_hashes) do
    query =
      from(
        block in Block,
        where: block.hash in ^block_hashes,
        # Enforce Block ShareLocks order (see docs: sharelocks.md)
        order_by: [asc: block.hash],
        lock: "FOR NO KEY UPDATE"
      )

    Repo.update_all(
      from(b in Block, join: s in subquery(query), on: b.hash == s.hash, select: b.number),
      [set: [is_empty: true, updated_at: Timex.now()]],
      timeout: @update_timeout
    )

    case PendingOperationsHelper.pending_operations_type() do
      "blocks" ->
        block_hashes
        |> PendingOperationsHelper.block_hash_in_query()
        |> Repo.delete_all()

      "transactions" ->
        :ok
    end
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
      where: block.refetch_needed == false,
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

  defp unprocessed_empty_blocks_list_query(limit) do
    blocks_query = consensus_blocks_with_nil_is_empty_query(limit)

    query =
      from(q in subquery(blocks_query),
        left_join: transaction in Transaction,
        on: q.number == transaction.block_number,
        where: is_nil(transaction.block_number),
        select: {q.number, q.hash},
        distinct: q.number,
        order_by: [asc: q.hash]
      )

    query
    |> Repo.all(timeout: :infinity)
  end

  defp limit do
    Application.get_env(:indexer, __MODULE__)[:batch_size]
  end
end
