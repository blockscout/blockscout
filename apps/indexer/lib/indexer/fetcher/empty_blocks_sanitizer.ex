# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.EmptyBlocksSanitizer do
  @moduledoc """
  Periodically checks empty blocks starting from the head of the chain, detects for which blocks transactions should be refetched
  and set refetch_needed=true for block in order to refetch transactions.

  The blocks that the node fails to return are left out of the next batches until fewer than a batch of
  unchecked blocks is left, so they don't block the check of the rest. Then the next pass requests them again.
  """

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  require Logger

  import Ecto.Query
  import EthereumJSONRPC, only: [id_to_params: 1, integer_to_quantity: 1, json_rpc: 2, quantity_to_integer: 1]

  alias EthereumJSONRPC.Block.ByNumber
  alias EthereumJSONRPC.Blocks
  alias Explorer.Chain.{Block, Hash, PendingOperationsHelper, Transaction}
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Repo

  @update_timeout 60_000

  @interval :timer.seconds(10)
  @batch_size 10
  @head_offset 1000
  # the list of the failed blocks is reset when it gets longer, e.g. if the node lacks a part of the history
  @max_failed_blocks 1000

  # `failed_block_hashes` are the blocks that the node failed to return during the current pass
  defstruct json_rpc_named_arguments: [], failed_block_hashes: []

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
    # For the first call we want it to start immediately
    # (don't affect implementation in any way, but helps tests not to flake)
    Kernel.send(self(), :sanitize_empty_blocks)

    state = %__MODULE__{
      json_rpc_named_arguments: Keyword.fetch!(opts, :json_rpc_named_arguments)
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_info(
        :sanitize_empty_blocks,
        %{json_rpc_named_arguments: json_rpc_named_arguments, failed_block_hashes: failed_block_hashes} = state
      ) do
    Logger.info("Start sanitizing of empty blocks. Batch size is #{limit()}",
      fetcher: :empty_blocks_to_refetch
    )

    failed_block_hashes = sanitize_empty_blocks(json_rpc_named_arguments, failed_block_hashes)

    Process.send_after(self(), :sanitize_empty_blocks, interval())

    {:noreply, %{state | failed_block_hashes: failed_block_hashes}}
  end

  defp sanitize_empty_blocks(json_rpc_named_arguments, failed_block_hashes) do
    unprocessed_non_empty_blocks_query = unprocessed_non_empty_blocks_query(limit())

    Repo.update_all(
      from(
        block in Block,
        where: block.hash in subquery(unprocessed_non_empty_blocks_query)
      ),
      [set: [is_empty: false, updated_at: Timex.now()]],
      timeout: :infinity
    )

    unprocessed_empty_blocks_list = unprocessed_empty_blocks_list_query(limit(), failed_block_hashes)
    new_failed_blocks = check_blocks_on_node(unprocessed_empty_blocks_list, json_rpc_named_arguments)

    next_failed_block_hashes(unprocessed_empty_blocks_list, new_failed_blocks, failed_block_hashes)
  end

  # Returns the blocks that the node failed to return
  defp check_blocks_on_node([], _json_rpc_named_arguments), do: []

  defp check_blocks_on_node(blocks, json_rpc_named_arguments) do
    id_to_params =
      blocks
      |> Enum.map(fn %{number: block_number} -> %{number: integer_to_quantity(block_number)} end)
      |> id_to_params()

    blocks_response =
      id_to_params
      |> Blocks.requests(&ByNumber.request(&1, false, false))
      |> json_rpc(json_rpc_named_arguments)

    case blocks_response do
      {:ok, result} ->
        {non_empty_blocks, empty_blocks, errors} = classify_blocks_from_result(result, id_to_params)
        process_non_empty_blocks(non_empty_blocks)
        process_empty_blocks(empty_blocks)
        process_errors(errors)

        Logger.info("Batch of empty blocks is sanitized",
          fetcher: :empty_blocks_to_refetch
        )

        returned_block_numbers = MapSet.new(non_empty_blocks ++ empty_blocks, & &1.number)
        Enum.reject(blocks, &MapSet.member?(returned_block_numbers, &1.number))

      {:error, reason} ->
        Logger.error(
          "Failed to fetch blocks batch: #{inspect(reason)}",
          fetcher: :empty_blocks_to_refetch
        )

        blocks
    end
  end

  # A batch smaller than the limit means that the unchecked blocks are over: the next pass
  # starts over and requests the failed blocks again.
  defp next_failed_block_hashes(blocks, new_failed_blocks, failed_block_hashes) do
    failed_block_hashes = Enum.map(new_failed_blocks, & &1.hash) ++ failed_block_hashes

    if Enum.count(blocks) < limit() or Enum.count(failed_block_hashes) > @max_failed_blocks do
      []
    else
      failed_block_hashes
    end
  end

  # Blocks with failed requests are only collected into errors: they keep `is_empty = nil`
  # and are requested again on the next pass.
  defp classify_blocks_from_result(result, id_to_params) do
    Enum.reduce(result, {[], [], []}, fn
      %{result: %{"transactions" => transactions} = block}, {non_empty_blocks, empty_blocks, errors} ->
        if Enum.empty?(transactions) do
          {non_empty_blocks, [block_fields(block) | empty_blocks], errors}
        else
          {[block_fields(block) | non_empty_blocks], empty_blocks, errors}
        end

      # the node doesn't have the block
      %{id: id, result: nil}, {non_empty_blocks, empty_blocks, errors} ->
        error = %{code: 404, message: "Not Found", data: id_to_params[id]}
        {non_empty_blocks, empty_blocks, [error | errors]}

      %{id: id, error: error}, {non_empty_blocks, empty_blocks, errors} ->
        {non_empty_blocks, empty_blocks, [Map.put(error, :data, id_to_params[id]) | errors]}
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

    block_hashes = Enum.map(empty_blocks, & &1.hash)
    mark_blocks_as_empty(block_hashes)
    refetch_blocks_from_other_forks(Enum.map(empty_blocks, & &1.number), block_hashes)
  end

  # The node has another block at the same height, so the consensus block in the DB is from a stale fork
  defp refetch_blocks_from_other_forks(block_numbers, node_block_hashes) do
    case Block.set_refetch_needed_for_other_consensus_blocks(block_numbers, node_block_hashes) do
      [] ->
        :ok

      refetched_block_numbers ->
        Logger.info(
          "Blocks with numbers #{inspect(refetched_block_numbers)} differ from the node's blocks at the same height. " <>
            "Setting refetch_needed = true for them to re-fetch.",
          fetcher: :empty_blocks_to_refetch
        )
    end
  end

  defp process_errors([]), do: :ok

  defp process_errors(errors) do
    Logger.error(
      "Failed to fetch #{Enum.count(errors)} blocks of the batch, they will be requested again on the next pass: " <>
        inspect(errors),
      fetcher: :empty_blocks_to_refetch
    )
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

  defp consensus_blocks_with_nil_is_empty_query(limit) do
    safe_block_number = BlockNumber.get_max() - head_offset()

    from(block in Block,
      as: :block,
      select: %{hash: block.hash, number: block.number},
      where: is_nil(block.is_empty),
      where: block.number <= ^safe_block_number,
      where: block.consensus == true,
      where: block.refetch_needed == false,
      limit: ^limit
    )
  end

  defp any_block_transactions_query do
    # NOTE: relies on parent_as(:block) set by the caller query (see consensus_blocks_with_nil_is_empty_query/1)
    from(
      t in Transaction,
      select: 1,
      where: parent_as(:block).hash == t.block_hash
    )
  end

  defp unprocessed_non_empty_blocks_query(limit) do
    candidate_blocks_query = consensus_blocks_with_nil_is_empty_query(limit)

    non_empty_blocks_query =
      from(
        block in candidate_blocks_query,
        where: exists(any_block_transactions_query())
      )

    # Inner Join is required in order to lock only `blocks` table.
    # As `non_empty_blocks_query` has WHERE condition on `transactions` table,
    # if you apply lock to the query, the `transactions` table is also locked
    # and that results in obtaining locks before the sort.
    from(
      block in Block,
      inner_join: non_empty_block in subquery(non_empty_blocks_query),
      on: block.hash == non_empty_block.hash,
      select: %{hash: block.hash},
      order_by: [asc: block.hash],
      lock: fragment("FOR NO KEY UPDATE OF ?", block)
    )
  end

  defp unprocessed_empty_blocks_list_query(limit, excluded_block_hashes) do
    candidate_blocks_query = consensus_blocks_with_nil_is_empty_query(limit)

    empty_blocks_query =
      from(
        block in candidate_blocks_query,
        where: not exists(any_block_transactions_query()),
        where: block.hash not in ^excluded_block_hashes
      )

    empty_blocks_query
    |> Repo.all(timeout: :infinity)
  end

  defp limit do
    Application.get_env(:indexer, __MODULE__)[:batch_size] || @batch_size
  end

  defp interval do
    Application.get_env(:indexer, __MODULE__)[:interval] || @interval
  end

  defp head_offset do
    Application.get_env(:indexer, __MODULE__)[:head_offset] || @head_offset
  end
end
