defmodule Indexer.Fetcher.PolygonEdge.DepositExecute do
  @moduledoc """
  Fills polygon_edge_deposit_executes DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Indexer.Fetcher.PolygonEdge, only: [fill_block_range: 5, get_block_number_by_tag: 3]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Log
  alias Explorer.Chain.PolygonEdge.DepositExecute
  alias Indexer.Fetcher.PolygonEdge

  @fetcher_name :polygon_edge_deposit_execute

  # 32-byte signature of the event StateSyncResult(uint256 indexed counter, bool indexed status, bytes message)
  @state_sync_result_event "0x31c652130602f3ce96ceaf8a4c2b8b49f049166c6fcf2eb31943a75ec7c936ae"

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
      DepositExecute,
      env,
      self(),
      env[:state_receiver],
      "StateReceiver",
      "polygon_edge_deposit_executes",
      "Deposit Executes",
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
      DepositExecute,
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
      {__MODULE__, DepositExecute},
      contract_address,
      json_rpc_named_arguments
    )

    if not safe_block_is_latest do
      # find and fill all events between "safe" and "latest" block (excluding "safe")
      {:ok, latest_block} = get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

      fill_block_range(
        safe_block + 1,
        latest_block,
        {__MODULE__, DepositExecute},
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
    Repo.delete_all(from(de in DepositExecute, where: de.l2_block_number >= ^starting_block))
  end

  @spec event_to_deposit_execute(binary(), binary(), binary(), binary()) :: map()
  def event_to_deposit_execute(second_topic, third_topic, l2_transaction_hash, l2_block_number) do
    %{
      msg_id: quantity_to_integer(second_topic),
      l2_transaction_hash: l2_transaction_hash,
      l2_block_number: quantity_to_integer(l2_block_number),
      success: quantity_to_integer(third_topic) != 0
    }
  end

  @spec find_and_save_entities(boolean(), binary(), non_neg_integer(), non_neg_integer(), list()) :: non_neg_integer()
  def find_and_save_entities(
        scan_db,
        state_receiver,
        block_start,
        block_end,
        json_rpc_named_arguments
      ) do
    executes =
      if scan_db do
        query =
          from(log in Log,
            select: {log.second_topic, log.third_topic, log.transaction_hash, log.block_number},
            where:
              log.first_topic == @state_sync_result_event and log.address_hash == ^state_receiver and
                log.block_number >= ^block_start and log.block_number <= ^block_end
          )

        query
        |> Repo.all(timeout: :infinity)
        |> Enum.map(fn {second_topic, third_topic, l2_transaction_hash, l2_block_number} ->
          event_to_deposit_execute(second_topic, third_topic, l2_transaction_hash, l2_block_number)
        end)
      else
        {:ok, result} =
          PolygonEdge.get_logs(
            block_start,
            block_end,
            state_receiver,
            @state_sync_result_event,
            json_rpc_named_arguments,
            100_000_000
          )

        Enum.map(result, fn event ->
          event_to_deposit_execute(
            Enum.at(event["topics"], 1),
            Enum.at(event["topics"], 2),
            event["transactionHash"],
            event["blockNumber"]
          )
        end)
      end

    {:ok, _} =
      Chain.import(%{
        polygon_edge_deposit_executes: %{params: executes},
        timeout: :infinity
      })

    Enum.count(executes)
  end

  @spec state_sync_result_event_signature() :: binary()
  def state_sync_result_event_signature do
    @state_sync_result_event
  end
end
