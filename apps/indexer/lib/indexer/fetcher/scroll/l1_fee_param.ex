defmodule Indexer.Fetcher.Scroll.L1FeeParam do
  @moduledoc """
    Fills scroll_l1_fee_params DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Explorer.Helper, only: [decode_data: 2]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Scroll.L1FeeParam, as: ScrollL1FeeParam
  alias Indexer.Helper

  @fetcher_name :scroll_l1_fee_params
  @counter_type "scroll_l1_fee_params_fetcher_last_block_number"
  @eth_get_logs_range_size 250

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

  @impl GenServer
  def handle_continue(json_rpc_named_arguments, state) do
    Logger.metadata(fetcher: @fetcher_name)

    env = Application.get_all_env(:indexer)[__MODULE__]

    if Helper.address_correct?(env[:gas_oracle]) do
      last_l2_block_number = Chain.get_last_fetched_counter(@counter_type)

      {safe_block, safe_block_is_latest} = Helper.get_safe_block(json_rpc_named_arguments)

      Process.send(self(), :find_events, [])

      {:noreply,
       %{
         start_block: min(Decimal.to_integer(Decimal.add(last_l2_block_number, 1)), safe_block),
         safe_block: safe_block,
         safe_block_is_latest: safe_block_is_latest,
         gas_oracle: env[:gas_oracle],
         json_rpc_named_arguments: json_rpc_named_arguments
       }}
    else
      Logger.error("L1 Gas Oracle contract address is invalid or not defined.")
      {:stop, :normal, state}
    end
  end

  @impl GenServer
  def handle_info(
        :find_events,
        %{
          start_block: start_block,
          safe_block: safe_block,
          safe_block_is_latest: safe_block_is_latest,
          gas_oracle: gas_oracle,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    # find and fill all events between start_block and "safe" block
    # the "safe" block can be "latest" (when safe_block_is_latest == true)
    scan_block_range(start_block, safe_block, gas_oracle, json_rpc_named_arguments)

    if not safe_block_is_latest do
      # find and fill all events between "safe" and "latest" block (excluding "safe")
      {:ok, latest_block} = Helper.get_block_number_by_tag("latest", json_rpc_named_arguments)
      scan_block_range(safe_block + 1, latest_block, gas_oracle, json_rpc_named_arguments)
    end

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  def handle_l2_reorg(starting_block) do
    Repo.delete_all(from(p in ScrollL1FeeParam, where: p.block_number >= ^starting_block))

    if not Decimal.lt?(Chain.get_last_fetched_counter(@counter_type), Decimal.new(starting_block)) do
      Chain.upsert_last_fetched_counter(%{
        counter_type: @counter_type,
        value: starting_block - 1
      })
    end
  end

  def event_to_param(first_topic, data, block_number, tx_index)
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
      tx_index: tx_index,
      name: name,
      value: value
    }
  end

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

  defp scan_block_range(l2_block_start, l2_block_end, gas_oracle, json_rpc_named_arguments) do
    chunks_number = ceil((l2_block_end - l2_block_start + 1) / @eth_get_logs_range_size)
    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    Enum.reduce(chunk_range, 0, fn current_chunk, count_acc ->
      chunk_start = l2_block_start + @eth_get_logs_range_size * current_chunk
      chunk_end = min(chunk_start + @eth_get_logs_range_size - 1, l2_block_end)

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

    Chain.upsert_last_fetched_counter(%{
      counter_type: @counter_type,
      value: block_end
    })

    Enum.count(l1_fee_params)
  end
end
