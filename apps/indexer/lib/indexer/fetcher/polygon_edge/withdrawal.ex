defmodule Indexer.Fetcher.PolygonEdge.Withdrawal do
  @moduledoc """
  Fills polygon_edge_withdrawals DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Explorer.Helper, only: [decode_data: 2]
  import Indexer.Fetcher.PolygonEdge, only: [fill_block_range: 5, get_block_number_by_tag: 3]

  alias ABI.TypeDecoder
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Log
  alias Explorer.Chain.PolygonEdge.Withdrawal
  alias Indexer.Fetcher.PolygonEdge

  @fetcher_name :polygon_edge_withdrawal

  # 32-byte signature of the event L2StateSynced(uint256 indexed id, address indexed sender, address indexed receiver, bytes data)
  @l2_state_synced_event "0xedaf3c471ebd67d60c29efe34b639ede7d6a1d92eaeb3f503e784971e67118a5"

  # 32-byte representation of withdrawal signature, keccak256("WITHDRAW")
  @withdrawal_signature "7a8dc26796a1e50e6e190b70259f58f6a4edd5b22280ceecc82b687b8e982869"

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
    Logger.metadata(fetcher: @fetcher_name)

    json_rpc_named_arguments = args[:json_rpc_named_arguments]
    env = Application.get_all_env(:indexer)[__MODULE__]

    PolygonEdge.init_l2(
      Withdrawal,
      env,
      self(),
      env[:state_sender],
      "L2StateSender",
      "polygon_edge_withdrawals",
      "Withdrawals",
      json_rpc_named_arguments
    )
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          start_block_l2: start_block_l2,
          contract_address: contract_address,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    PolygonEdge.fill_msg_id_gaps(
      start_block_l2,
      Withdrawal,
      __MODULE__,
      contract_address,
      json_rpc_named_arguments
    )

    Process.send(self(), :find_new_events, [])
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        :find_new_events,
        %{
          start_block: start_block,
          safe_block: safe_block,
          safe_block_is_latest: safe_block_is_latest,
          contract_address: contract_address,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    # find and fill all events between start_block and "safe" block
    # the "safe" block can be "latest" (when safe_block_is_latest == true)
    fill_block_range(
      start_block,
      safe_block,
      {__MODULE__, Withdrawal},
      contract_address,
      json_rpc_named_arguments
    )

    if not safe_block_is_latest do
      # find and fill all events between "safe" and "latest" block (excluding "safe")
      {:ok, latest_block} = get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

      fill_block_range(
        safe_block + 1,
        latest_block,
        {__MODULE__, Withdrawal},
        contract_address,
        json_rpc_named_arguments
      )
    end

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @spec remove(non_neg_integer()) :: no_return()
  def remove(starting_block) do
    Repo.delete_all(from(w in Withdrawal, where: w.l2_block_number >= ^starting_block))
  end

  @spec event_to_withdrawal(binary(), map(), binary(), binary()) :: map()
  def event_to_withdrawal(second_topic, data, l2_transaction_hash, l2_block_number) do
    [data_bytes] = decode_data(data, [:bytes])

    sig = binary_part(data_bytes, 0, 32)

    {from, to} =
      if Base.encode16(sig, case: :lower) == @withdrawal_signature do
        [_sig, _root_token, sender, receiver, _amount] =
          TypeDecoder.decode_raw(data_bytes, [{:bytes, 32}, :address, :address, :address, {:uint, 256}])

        {sender, receiver}
      else
        {nil, nil}
      end

    %{
      msg_id: quantity_to_integer(second_topic),
      from: from,
      to: to,
      l2_transaction_hash: l2_transaction_hash,
      l2_block_number: quantity_to_integer(l2_block_number)
    }
  end

  @spec find_and_save_entities(boolean(), binary(), non_neg_integer(), non_neg_integer(), list()) :: non_neg_integer()
  def find_and_save_entities(
        scan_db,
        state_sender,
        block_start,
        block_end,
        json_rpc_named_arguments
      ) do
    withdrawals =
      if scan_db do
        query =
          from(log in Log,
            select: {log.second_topic, log.data, log.transaction_hash, log.block_number},
            where:
              log.first_topic == @l2_state_synced_event and log.address_hash == ^state_sender and
                log.block_number >= ^block_start and log.block_number <= ^block_end
          )

        query
        |> Repo.all(timeout: :infinity)
        |> Enum.map(fn {second_topic, data, l2_transaction_hash, l2_block_number} ->
          event_to_withdrawal(second_topic, data, l2_transaction_hash, l2_block_number)
        end)
      else
        {:ok, result} =
          PolygonEdge.get_logs(
            block_start,
            block_end,
            state_sender,
            @l2_state_synced_event,
            json_rpc_named_arguments,
            100_000_000
          )

        Enum.map(result, fn event ->
          event_to_withdrawal(
            Enum.at(event["topics"], 1),
            event["data"],
            event["transactionHash"],
            event["blockNumber"]
          )
        end)
      end

    {:ok, _} =
      Chain.import(%{
        polygon_edge_withdrawals: %{params: withdrawals},
        timeout: :infinity
      })

    Enum.count(withdrawals)
  end

  @spec l2_state_synced_event_signature() :: binary()
  def l2_state_synced_event_signature do
    @l2_state_synced_event
  end
end
