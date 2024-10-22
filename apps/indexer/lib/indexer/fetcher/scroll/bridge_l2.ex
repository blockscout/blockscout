defmodule Indexer.Fetcher.Scroll.BridgeL2 do
  @moduledoc """
  The module for scanning Scroll RPC node on L2 for the message logs (events), parsing them,
  and importing to the database (scroll_bridge table).

  The main function splits the whole block range by chunks and scans L2 Scroll Messenger contract
  for the message logs (events) for each chunk. The found events are handled and then imported to the
  `scroll_bridge` database table.

  After historical block range is covered, the process switches to realtime mode and
  searches for the message events in every new block. Reorg blocks are taken into account.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  alias Explorer.Chain.Scroll.{Bridge, Reader}
  alias Explorer.Repo
  alias Indexer.Fetcher.RollupL1ReorgMonitor
  alias Indexer.Fetcher.Scroll.Bridge, as: BridgeFetcher
  alias Indexer.Helper

  @fetcher_name :scroll_bridge_l2

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
  def handle_continue(json_rpc_named_arguments, _state) do
    Logger.metadata(fetcher: @fetcher_name)
    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    Process.send_after(self(), :init_with_delay, 2000)
    {:noreply, %{json_rpc_named_arguments: json_rpc_named_arguments}}
  end

  # Validates parameters and initiates searching of the events.
  #
  # When first launch, the events searching will start from the first block of the chain
  # and end on the `latest` one. If this is not the first launch, the process will start
  # from the block which was the last on the previous launch.
  @impl GenServer
  def handle_info(:init_with_delay, %{json_rpc_named_arguments: json_rpc_named_arguments} = state) do
    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:messenger_contract_address_is_valid, true} <-
           {:messenger_contract_address_is_valid, Helper.address_correct?(env[:messenger_contract])},
         {last_l2_block_number, last_l2_transaction_hash} = Reader.last_l2_item(),
         {:ok, block_check_interval, _} <- Helper.get_block_check_interval(json_rpc_named_arguments),
         {:ok, latest_block} = Helper.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000),
         {:ok, last_l2_tx} <- Helper.get_transaction_by_hash(last_l2_transaction_hash, json_rpc_named_arguments),
         {:l2_tx_not_found, false} <- {:l2_tx_not_found, !is_nil(last_l2_transaction_hash) && is_nil(last_l2_tx)} do
      Process.send(self(), :continue, [])

      {:noreply,
       %{
         block_check_interval: block_check_interval,
         messenger_contract: env[:messenger_contract],
         json_rpc_named_arguments: json_rpc_named_arguments,
         end_block: latest_block,
         start_block: max(1, last_l2_block_number)
       }}
    else
      {:messenger_contract_address_is_valid, false} ->
        Logger.error("L2ScrollMessenger contract address is invalid or not defined.")
        {:stop, :normal, state}

      {:error, error_data} ->
        Logger.error(
          "Cannot get last L2 transaction from RPC by its hash, latest block, or block by number due to RPC error: #{inspect(error_data)}"
        )

        {:stop, :normal, state}

      {:l2_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L2 transaction from RPC by its hash. Probably, there was a reorg on L2 chain. Please, check scroll_bridge table."
        )

        {:stop, :normal, state}
    end
  end

  # See the description of the `loop` function.
  @impl GenServer
  def handle_info(:continue, state) do
    BridgeFetcher.loop(__MODULE__, state)
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @doc """
    Handles L2 block reorg: removes all Withdrawal rows from the `scroll_bridge` table
    created beginning from the reorged block.

    ## Parameters
    - `reorg_block`: the block number where reorg has occurred.

    ## Returns
    - nothing
  """
  def reorg_handle(reorg_block) do
    {deleted_count, _} =
      Repo.delete_all(from(b in Bridge, where: b.type == :withdrawal and b.block_number >= ^reorg_block))

    if deleted_count > 0 do
      Logger.warning(
        "As L2 reorg was detected, some withdrawals with block_number >= #{reorg_block} were removed from scroll_bridge table. Number of removed rows: #{deleted_count}."
      )
    end

    RollupL1ReorgMonitor.reorg_block_push(reorg_block, __MODULE__)
  end
end
