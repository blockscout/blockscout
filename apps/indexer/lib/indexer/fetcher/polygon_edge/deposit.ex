defmodule Indexer.Fetcher.PolygonEdge.Deposit do
  @moduledoc """
  Fills polygon_edge_deposits DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Explorer.Helper, only: [decode_data: 2]

  alias ABI.TypeDecoder
  alias EthereumJSONRPC.Block.ByNumber
  alias EthereumJSONRPC.Blocks
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Chain.PolygonEdge.Deposit
  alias Indexer.Fetcher.PolygonEdge

  @fetcher_name :polygon_edge_deposit

  # 32-byte signature of the event StateSynced(uint256 indexed id, address indexed sender, address indexed receiver, bytes data)
  @state_synced_event "0xd1d7f6609674cc5871fdb4b0bcd4f0a214118411de9e38983866514f22659165"

  # 32-byte representation of deposit signature, keccak256("DEPOSIT")
  @deposit_signature "87a7811f4bfedea3d341ad165680ae306b01aaeacc205d227629cf157dd9f821"

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
    Logger.metadata(fetcher: @fetcher_name)

    env = Application.get_all_env(:indexer)[__MODULE__]

    Subscriber.to(:polygon_edge_reorg_block, :realtime)

    PolygonEdge.init_l1(
      Deposit,
      env,
      self(),
      env[:state_sender],
      "State Sender",
      "polygon_edge_deposits",
      "Deposits"
    )
  end

  @impl GenServer
  def handle_info(:continue, state) do
    PolygonEdge.handle_continue(state, @state_synced_event, __MODULE__, @fetcher_name)
  end

  @impl GenServer
  def handle_info({:chain_event, :polygon_edge_reorg_block, :realtime, block_number}, state) do
    PolygonEdge.reorg_block_push(@fetcher_name, block_number)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @spec prepare_events(list(), list()) :: list()
  def prepare_events(events, json_rpc_named_arguments) do
    Enum.map(events, fn event ->
      [data_bytes] = decode_data(event["data"], [:bytes])

      sig = binary_part(data_bytes, 0, 32)

      l1_block_number = quantity_to_integer(event["blockNumber"])

      {from, to, l1_timestamp} =
        if Base.encode16(sig, case: :lower) == @deposit_signature do
          timestamps = get_timestamps_by_events(events, json_rpc_named_arguments)

          [_sig, _root_token, sender, receiver, _amount] =
            TypeDecoder.decode_raw(data_bytes, [{:bytes, 32}, :address, :address, :address, {:uint, 256}])

          {sender, receiver, Map.get(timestamps, l1_block_number)}
        else
          {nil, nil, nil}
        end

      %{
        msg_id: quantity_to_integer(Enum.at(event["topics"], 1)),
        from: from,
        to: to,
        l1_transaction_hash: event["transactionHash"],
        l1_timestamp: l1_timestamp,
        l1_block_number: l1_block_number
      }
    end)
  end

  defp get_blocks_by_events(events, json_rpc_named_arguments, retries) do
    request =
      events
      |> Enum.reduce(%{}, fn event, acc ->
        Map.put(acc, event["blockNumber"], 0)
      end)
      |> Stream.map(fn {block_number, _} -> %{number: block_number} end)
      |> Stream.with_index()
      |> Enum.into(%{}, fn {params, id} -> {id, params} end)
      |> Blocks.requests(&ByNumber.request(&1, false, false))

    error_message = &"Cannot fetch blocks with batch request. Error: #{inspect(&1)}. Request: #{inspect(request)}"

    case PolygonEdge.repeated_request(request, error_message, json_rpc_named_arguments, retries) do
      {:ok, results} -> Enum.map(results, fn %{result: result} -> result end)
      {:error, _} -> []
    end
  end

  defp get_timestamps_by_events(events, json_rpc_named_arguments) do
    events
    |> get_blocks_by_events(json_rpc_named_arguments, 100_000_000)
    |> Enum.reduce(%{}, fn block, acc ->
      block_number = quantity_to_integer(Map.get(block, "number"))
      {:ok, timestamp} = DateTime.from_unix(quantity_to_integer(Map.get(block, "timestamp")))
      Map.put(acc, block_number, timestamp)
    end)
  end
end
