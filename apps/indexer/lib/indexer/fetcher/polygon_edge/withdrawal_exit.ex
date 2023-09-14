defmodule Indexer.Fetcher.PolygonEdge.WithdrawalExit do
  @moduledoc """
  Fills polygon_edge_withdrawal_exits DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Chain.PolygonEdge.WithdrawalExit
  alias Indexer.Fetcher.PolygonEdge

  @fetcher_name :polygon_edge_withdrawal_exit

  # 32-byte signature of the event ExitProcessed(uint256 indexed id, bool indexed success, bytes returnData)
  @exit_processed_event "0x8bbfa0c9bee3785c03700d2a909592286efb83fc7e7002be5764424b9842f7ec"

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
      WithdrawalExit,
      env,
      self(),
      env[:exit_helper],
      "Exit Helper",
      "polygon_edge_withdrawal_exits",
      "Withdrawals"
    )
  end

  @impl GenServer
  def handle_info(:continue, state) do
    PolygonEdge.handle_continue(state, @exit_processed_event, __MODULE__, @fetcher_name)
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
  def prepare_events(events, _) do
    Enum.map(events, fn event ->
      %{
        msg_id: quantity_to_integer(Enum.at(event["topics"], 1)),
        l1_transaction_hash: event["transactionHash"],
        l1_block_number: quantity_to_integer(event["blockNumber"]),
        success: quantity_to_integer(Enum.at(event["topics"], 2)) != 0
      }
    end)
  end
end
