defmodule Indexer.Fetcher.Scroll.L1FeeParam do
  @moduledoc """
    Fills scroll_l1_fee_params DB table.

    The table stores points in the chain (block number and transaction index within it)
    when L1 Gas Oracle contract parameters were changed (and the new values of the changed
    parameters). These points and values are then used by API to correctly display L1 fee
    parameters of L2 transaction (such as `overhead`, `scalar`, etc.)

    This fetcher handles the events that were not handled by the realtime block fetcher
    (namely `Indexer.Transform.Scroll.L1FeeParams` module). There are three possible cases when it happens:
    1. A Blockscout instance is deployed for a chain that already has blocks.
    2. A Blockscout instance is upgraded, and the functionality to discover fee parameter changes only becomes available after the upgrade.
    3. The block fetcher process (or entire instance) was halted for some time.

    Example of the parameter value change:

    Let's assume that the `scalar` parameter is initially set to 100. An owner decided
    to change it to 200. It initiates a transaction that is included into block number 800
    under index 3. All transactions starting from block number 800 and index 4 will have
    the scalar equal to 200. All transactions before index 3 of the block 800 (and preceding
    blocks) will have the scalar equal to 100.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Explorer.Helper, only: [decode_data: 2]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Data
  alias Explorer.Chain.Scroll.L1FeeParam, as: ScrollL1FeeParam
  alias Indexer.Helper

  @fetcher_name :scroll_l1_fee_params

  # 32-byte signature of the event OverheadUpdated(uint256 overhead)
  @overhead_updated_event "0x32740b35c0ea213650f60d44366b4fb211c9033b50714e4a1d34e65d5beb9bb4"

  # 32-byte signature of the event ScalarUpdated(uint256 scalar)
  @scalar_updated_event "0x3336cd9708eaf2769a0f0dc0679f30e80f15dcd88d1921b5a16858e8b85c591a"

  # 32-byte signature of the event CommitScalarUpdated(uint256 scalar)
  @commit_scalar_updated_event "0x2ab3f5a4ebbcbf3c24f62f5454f52f10e1a8c9dcc5acac8f19199ce881a6a108"

  # 32-byte signature of the event BlobScalarUpdated(uint256 scalar)
  @blob_scalar_updated_event "0x6b332a036d8c3ead57dcb06c87243bd7a2aed015ddf2d0528c2501dae56331aa"

  # 32-byte signature of the event L1BaseFeeUpdated(uint256 l1BaseFee)
  @l1_base_fee_updated_event "0x351fb23757bb5ea0546c85b7996ddd7155f96b939ebaa5ff7bc49c75f27f2c44"

  # 32-byte signature of the event L1BlobBaseFeeUpdated(uint256 l1BlobBaseFee)
  @l1_blob_base_fee_updated_event "0x9a14bfb5d18c4c3cf14cae19c23d7cf1bcede357ea40ca1f75cd49542c71c214"

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
  def init(args) do
    json_rpc_named_arguments = args[:json_rpc_named_arguments]
    {:ok, %{}, {:continue, json_rpc_named_arguments}}
  end

  # Validates L1 Gas Oracle contract address and initiates searching of gas oracle events.
  #
  # When first launch, the events searching will start from the first block of the chain
  # and end on the `safe` block (or `latest` one if `safe` is not available).
  # If this is not the first launch, the process will start from the block which was
  # the last on the previous launch (plus one). The block from the previous launch
  # is stored in the `last_fetched_counters` database table.
  #
  # ## Parameters
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection on L2.
  # - `state`: The current state of the fetcher.
  #
  # ## Returns
  # - `{:noreply, new_state}` where the searching parameters are defined.
  # - `{:stop, :normal, state}` in case of invalid L1 Gas Oracle contract address.
  @impl GenServer
  def handle_continue(json_rpc_named_arguments, state) do
    Logger.metadata(fetcher: @fetcher_name)

    env = Application.get_all_env(:indexer)[__MODULE__]

    if Helper.address_correct?(env[:gas_oracle]) do
      last_l2_block_number = ScrollL1FeeParam.last_l2_block_number()

      {safe_block, safe_block_is_latest} = Helper.get_safe_block(json_rpc_named_arguments)

      Process.send(self(), :find_events, [])

      {:noreply,
       %{
         start_block: min(last_l2_block_number + 1, safe_block),
         safe_block: safe_block,
         safe_block_is_latest: safe_block_is_latest,
         gas_oracle: env[:gas_oracle],
         eth_get_logs_range_size:
           Application.get_all_env(:indexer)[Indexer.Fetcher.Scroll][:l2_eth_get_logs_range_size],
         json_rpc_named_arguments: json_rpc_named_arguments
       }}
    else
      Logger.error("L1 Gas Oracle contract address is invalid or not defined.")
      {:stop, :normal, state}
    end
  end

  # Scans the L1 Gas Oracle contract for the events and saves the found parameter changes
  # into `scroll_l1_fee_params` database table.
  #
  # The scanning process starts from the `start_block` defined by `handle_continue` function
  # and ends with the latest one. The `safe_block` can be the latest block if the `safe` one
  # is not available on the chain (in this case `safe_block_is_latest` is true). So the process
  # works in the following block ranges: `start_block..safe_block` and `(safe_block + 1)..latest_block`
  # or `start_block..latest`.
  #
  # ## Parameters
  # - `:find_events`: The message that triggers the event scanning process.
  # - `state`: The current state of the fetcher containing the searching parameters.
  #
  # ## Returns
  # - `{:stop, :normal, state}` as a signal for the fetcher to stop working after all blocks are handled.
  @impl GenServer
  def handle_info(
        :find_events,
        %{
          start_block: start_block,
          safe_block: safe_block,
          safe_block_is_latest: safe_block_is_latest,
          gas_oracle: gas_oracle,
          eth_get_logs_range_size: eth_get_logs_range_size,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    # find and fill all events between start_block and "safe" block
    # the "safe" block can be "latest" (when safe_block_is_latest == true)
    scan_block_range(start_block, safe_block, gas_oracle, eth_get_logs_range_size, json_rpc_named_arguments)

    if not safe_block_is_latest do
      # find and fill all events between "safe" and "latest" block (excluding "safe")
      {:ok, latest_block} = Helper.get_block_number_by_tag("latest", json_rpc_named_arguments)
      scan_block_range(safe_block + 1, latest_block, gas_oracle, eth_get_logs_range_size, json_rpc_named_arguments)
    end

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @doc """
    Handles L2 block reorg: removes all rows from the `scroll_l1_fee_params` table
    created beginning from the reorged block, and accordingly reduces the last
    block number defined in the `last_fetched_counters` database table.

    ## Parameters
    - `starting_block`: the block number where reorg has occurred.

    ## Returns
    - nothing
  """
  @spec handle_l2_reorg(non_neg_integer()) :: any()
  def handle_l2_reorg(starting_block) do
    Repo.delete_all(from(p in ScrollL1FeeParam, where: p.block_number >= ^starting_block))

    if ScrollL1FeeParam.last_l2_block_number() >= starting_block do
      ScrollL1FeeParam.set_last_l2_block_number(starting_block - 1)
    end
  end

  @doc """
    Converts event parameters and data into the map which can be
    used to write a new row to the `scroll_l1_fee_params` table.

    ## Parameters
    - `first_topic`: The 32-byte hash of an event signature (in the form of `0x` prefixed hex string).
    - `data`: The event data containing a changed parameter.
    - `block_number`: The number of the block when the event transaction appeared.
    - `transaction_index`: The event transaction index withing the `block_number` block.

    ## Returns
    - A map for one row for `Chain.import` function.
  """
  @spec event_to_param(binary(), Data.t(), non_neg_integer(), non_neg_integer()) :: ScrollL1FeeParam.to_import()
  def event_to_param(first_topic, data, block_number, transaction_index)
      when first_topic in [
             @overhead_updated_event,
             @scalar_updated_event,
             @commit_scalar_updated_event,
             @blob_scalar_updated_event,
             @l1_base_fee_updated_event,
             @l1_blob_base_fee_updated_event
           ] do
    name =
      case first_topic do
        @overhead_updated_event -> :overhead
        @scalar_updated_event -> :scalar
        @commit_scalar_updated_event -> :commit_scalar
        @blob_scalar_updated_event -> :blob_scalar
        @l1_base_fee_updated_event -> :l1_base_fee
        @l1_blob_base_fee_updated_event -> :l1_blob_base_fee
      end

    [value] = decode_data(data, [{:uint, 256}])

    %{
      block_number: block_number,
      transaction_index: transaction_index,
      name: name,
      value: value
    }
  end

  @doc """
    Returns a list of signatures of the events that can be emitted
    by L1 Gas Oracle contract.
  """
  @spec event_signatures() :: [binary()]
  def event_signatures do
    [
      @overhead_updated_event,
      @scalar_updated_event,
      @commit_scalar_updated_event,
      @blob_scalar_updated_event,
      @l1_base_fee_updated_event,
      @l1_blob_base_fee_updated_event
    ]
  end

  # Scans the L1 Gas Oracle contract for the events and saves the found parameter changes
  # into `scroll_l1_fee_params` database table for the given L2 block range.
  #
  # The scanning process starts from the `l2_block_start` and ends with the `l2_block_end`.
  # The block range is divided by chunks to avoid RPC node overloading.
  #
  # ## Parameters
  # - `l2_block_start`: The start L2 block of the range.
  # - `l2_block_end`: The end L2 block of the range.
  # - `gas_oracle`: The L1 Gas Oracle contract address.
  # - `eth_get_logs_range_size`: Max size of the blocks chunk.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  #
  # ## Returns
  # - Nothing is returned.
  @spec scan_block_range(
          non_neg_integer(),
          non_neg_integer(),
          binary(),
          non_neg_integer(),
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: any()
  defp scan_block_range(l2_block_start, l2_block_end, gas_oracle, eth_get_logs_range_size, json_rpc_named_arguments) do
    chunks_number = ceil((l2_block_end - l2_block_start + 1) / eth_get_logs_range_size)
    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    Enum.reduce(chunk_range, 0, fn current_chunk, count_acc ->
      chunk_start = l2_block_start + eth_get_logs_range_size * current_chunk
      chunk_end = min(chunk_start + eth_get_logs_range_size - 1, l2_block_end)

      Helper.log_blocks_chunk_handling(chunk_start, chunk_end, l2_block_start, l2_block_end, nil, :L2)

      count =
        find_and_save_params(
          gas_oracle,
          chunk_start,
          chunk_end,
          json_rpc_named_arguments
        )

      Helper.log_blocks_chunk_handling(
        chunk_start,
        chunk_end,
        l2_block_start,
        l2_block_end,
        "#{count} event(s) for parameters update",
        :L2
      )

      count_acc + count
    end)
  end

  # Scans the L1 Gas Oracle contract for the events and saves the found parameter changes
  # into `scroll_l1_fee_params` database table for the given L2 block range.
  #
  # The scanning process starts from the `block_start` and ends with the `block_end`.
  # The `block_end` block number is stored in the `last_fetched_counters` database table
  # to be able to start from that point at the next launch of the fetcher.
  #
  # ## Parameters
  # - `gas_oracle`: The L1 Gas Oracle contract address.
  # - `block_start`: The start L2 block of the range.
  # - `block_end`: The end L2 block of the range.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  #
  # ## Returns
  # - The number of found and saved items.
  @spec find_and_save_params(binary(), non_neg_integer(), non_neg_integer(), EthereumJSONRPC.json_rpc_named_arguments()) ::
          non_neg_integer()
  defp find_and_save_params(
         gas_oracle,
         block_start,
         block_end,
         json_rpc_named_arguments
       ) do
    {:ok, result} =
      Helper.get_logs(
        block_start,
        block_end,
        gas_oracle,
        [event_signatures()],
        json_rpc_named_arguments
      )

    l1_fee_params =
      Enum.map(result, fn event ->
        event_to_param(
          Enum.at(event["topics"], 0),
          event["data"],
          quantity_to_integer(event["blockNumber"]),
          quantity_to_integer(event["transactionIndex"])
        )
      end)

    {:ok, _} =
      Chain.import(%{
        scroll_l1_fee_params: %{params: l1_fee_params},
        timeout: :infinity
      })

    ScrollL1FeeParam.set_last_l2_block_number(block_end)

    Enum.count(l1_fee_params)
  end
end
