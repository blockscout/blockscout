defmodule Indexer.Fetcher.Optimism.OutputRoot do
  @moduledoc """
  Fills op_output_roots DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  alias Explorer.Application.Constants
  alias Explorer.{Chain, Helper, Repo}
  alias Explorer.Chain.Optimism.{DisputeGame, OutputRoot}
  alias Explorer.Chain.RollupReorgMonitorQueue
  alias Indexer.Fetcher.Optimism
  alias Indexer.Helper, as: IndexerHelper

  @fetcher_name :optimism_output_roots
  @stop_constant_key "optimism_output_roots_stopped"
  @counter_type "optimism_output_roots_fetcher_last_l1_block_hash"
  @empty_hash "0x0000000000000000000000000000000000000000000000000000000000000000"

  # 32-byte signature of the event OutputProposed(bytes32 indexed outputRoot, uint256 indexed l2OutputIndex, uint256 indexed l2BlockNumber, uint256 l1Timestamp)
  @output_proposed_event "0xa7aaf2512769da4e444e3de247be2564225c2e7a8f74cfe528e46e17d24868e2"

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(_args) do
    {:ok, %{}, {:continue, :ok}}
  end

  @impl GenServer
  def handle_continue(:ok, _state) do
    Logger.metadata(fetcher: @fetcher_name)

    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    :timer.sleep(2000)

    if Constants.get_constant_value(@stop_constant_key) == "true" do
      Logger.warning("#{__MODULE__} will not start because dispute games exist.")
      {:stop, :normal, %{}}
    else
      env = Application.get_all_env(:indexer)[__MODULE__]
      Optimism.init_continue(env[:output_oracle], __MODULE__)
    end
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          contract_address: output_oracle,
          block_check_interval: block_check_interval,
          start_block: start_block,
          end_block: end_block,
          json_rpc_named_arguments: json_rpc_named_arguments,
          eth_get_logs_range_size: eth_get_logs_range_size,
          stop: stop
        } = state
      ) do
    # credo:disable-for-next-line
    time_before = Timex.now()

    chunks_number = ceil((end_block - start_block + 1) / eth_get_logs_range_size)
    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    last_written_block =
      chunk_range
      |> Enum.reduce_while(start_block - 1, fn current_chunk, _ ->
        chunk_start = start_block + eth_get_logs_range_size * current_chunk
        chunk_end = min(chunk_start + eth_get_logs_range_size - 1, end_block)

        if chunk_end >= chunk_start do
          IndexerHelper.log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, :L1)

          {:ok, result} =
            IndexerHelper.get_logs(
              chunk_start,
              chunk_end,
              output_oracle,
              [@output_proposed_event],
              json_rpc_named_arguments,
              0,
              IndexerHelper.infinite_retries_number()
            )

          output_roots = events_to_output_roots(result)

          {:ok, _} =
            Chain.import(%{
              optimism_output_roots: %{params: output_roots},
              timeout: :infinity
            })

          IndexerHelper.log_blocks_chunk_handling(
            chunk_start,
            chunk_end,
            start_block,
            end_block,
            "#{Enum.count(output_roots)} OutputProposed event(s)",
            :L1
          )
        end

        reorg_block = RollupReorgMonitorQueue.reorg_block_pop(__MODULE__)

        if !is_nil(reorg_block) && reorg_block > 0 do
          {deleted_count, _} = Repo.delete_all(from(r in OutputRoot, where: r.l1_block_number >= ^reorg_block))

          log_deleted_rows_count(reorg_block, deleted_count)

          Optimism.set_last_block_hash(@empty_hash, @counter_type)

          {:halt, if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end)}
        else
          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          if chunk_end >= chunk_start do
            Optimism.set_last_block_hash_by_number(chunk_end, @counter_type, json_rpc_named_arguments)
          end

          {:cont, chunk_end}
        end
      end)

    if stop do
      Logger.warning("#{__MODULE__} is being stopped because dispute games exist.")
      Constants.set_constant_value(@stop_constant_key, "true")
      {:stop, :normal, state}
    else
      new_start_block = last_written_block + 1
      new_end_block = IndexerHelper.fetch_latest_l1_block_number(json_rpc_named_arguments)

      delay =
        if new_end_block == last_written_block do
          # there is no new block, so wait for some time to let the chain issue the new block
          max(block_check_interval - Timex.diff(Timex.now(), time_before, :milliseconds), 0)
        else
          0
        end

      Process.send_after(self(), :continue, delay)

      {:noreply, %{state | start_block: new_start_block, end_block: new_end_block, stop: dispute_games_exist?()}}
    end
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  defp dispute_games_exist? do
    DisputeGame.get_last_known_index() >= 0
  end

  defp events_to_output_roots(events) do
    Enum.map(events, fn event ->
      [l1_timestamp] = Helper.decode_data(event["data"], [{:uint, 256}])
      {:ok, l1_timestamp} = DateTime.from_unix(l1_timestamp)

      %{
        l2_output_index: quantity_to_integer(Enum.at(event["topics"], 2)),
        l2_block_number: quantity_to_integer(Enum.at(event["topics"], 3)),
        l1_transaction_hash: event["transactionHash"],
        l1_timestamp: l1_timestamp,
        l1_block_number: quantity_to_integer(event["blockNumber"]),
        output_root: Enum.at(event["topics"], 1)
      }
    end)
  end

  defp log_deleted_rows_count(reorg_block, count) do
    if count > 0 do
      Logger.warning(
        "As L1 reorg was detected, all rows with l1_block_number >= #{reorg_block} were removed from the op_output_roots table. Number of removed rows: #{count}."
      )
    end
  end

  @doc """
    Determines the last saved L1 block number, the last saved transaction hash, and the transaction info for Output Roots.

    Used by the `Indexer.Fetcher.Optimism` module to start fetching from a correct block number
    after reorg has occurred.

    ## Parameters
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
                                  Used to get transaction info by its hash from the RPC node.

    ## Returns
    - A tuple `{last_block_number, last_transaction_hash, last_transaction}` where
      `last_block_number` is the last block number found in the corresponding table (0 if not found),
      `last_transaction_hash` is the last transaction hash found in the corresponding table (nil if not found),
      `last_transaction` is the transaction info got from the RPC (nil if not found).
    - A tuple `{:error, message}` in case the `eth_getTransactionByHash` RPC request failed.
  """
  @spec get_last_l1_item(EthereumJSONRPC.json_rpc_named_arguments()) ::
          {non_neg_integer(), binary() | nil, map() | nil} | {:error, any()}
  def get_last_l1_item(json_rpc_named_arguments) do
    Optimism.get_last_item(
      :L1,
      &OutputRoot.last_root_l1_block_number_query/0,
      &OutputRoot.remove_roots_query/1,
      json_rpc_named_arguments,
      @counter_type
    )
  end

  @doc """
    Returns L1 RPC URL for this module.
  """
  @spec l1_rpc_url() :: binary() | nil
  def l1_rpc_url do
    Optimism.l1_rpc_url()
  end

  @doc """
    Determines if `Indexer.Fetcher.RollupL1ReorgMonitor` module must be up
    before this fetcher starts.

    ## Returns
    - `true` if the reorg monitor must be active, `false` otherwise.
  """
  @spec requires_l1_reorg_monitor?() :: boolean()
  def requires_l1_reorg_monitor? do
    Optimism.requires_l1_reorg_monitor?()
  end
end
