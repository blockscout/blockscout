defmodule Indexer.Fetcher.Scroll.BridgeL1 do
  @moduledoc """
  The module for scanning Scroll RPC node on L1 for the message logs (events), parsing them,
  and importing to the database (scroll_bridge table).

  The events discovery logic is located in the `Indexer.Fetcher.Scroll.Bridge` module whereas this module
  only prepares required parameters for the discovery loop.

  The main function splits the whole block range by chunks and scans L1 Scroll Messenger contract
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
  alias Indexer.Fetcher.Scroll.Helper, as: ScrollHelper
  alias Indexer.Helper

  @fetcher_name :scroll_bridge_l1

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
  def handle_continue(_, state) do
    Logger.metadata(fetcher: @fetcher_name)
    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    Process.send_after(self(), :init_with_delay, 2000)
    {:noreply, state}
  end

  # Validates parameters and initiates searching of the events.
  #
  # When first launch, the events searching will start from the given start block
  # and end on the `safe` block (or `latest` one if `safe` is not available).
  # If this is not the first launch, the process will start from the block which was
  # the last on the previous launch.
  @impl GenServer
  def handle_info(:init_with_delay, _state) do
    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:start_block_undefined, false} <- {:start_block_undefined, is_nil(env[:start_block])},
         _ <- RollupL1ReorgMonitor.wait_for_start(__MODULE__),
         rpc = l1_rpc_url(),
         {:rpc_undefined, false} <- {:rpc_undefined, is_nil(rpc)},
         {:messenger_contract_address_is_valid, true} <-
           {:messenger_contract_address_is_valid, Helper.address_correct?(env[:messenger_contract])},
         start_block = env[:start_block],
         true <- start_block > 0,
         {last_l1_block_number, last_l1_transaction_hash} = Reader.last_l1_bridge_item(),
         json_rpc_named_arguments = Helper.json_rpc_named_arguments(rpc),
         {:ok, block_check_interval, safe_block} <- Helper.get_block_check_interval(json_rpc_named_arguments),
         {:start_block_valid, true, _, _} <-
           {:start_block_valid,
            (start_block <= last_l1_block_number || last_l1_block_number == 0) && start_block <= safe_block,
            last_l1_block_number, safe_block},
         {:ok, last_l1_transaction} <-
           Helper.get_transaction_by_hash(last_l1_transaction_hash, json_rpc_named_arguments),
         # here we check for the last known L1 transaction existence to make sure there wasn't reorg
         # on L1 while the instance was down, and so we can use `last_l1_block_number` as the starting point
         {:l1_transaction_not_found, false} <-
           {:l1_transaction_not_found, !is_nil(last_l1_transaction_hash) && is_nil(last_l1_transaction)} do
      Process.send(self(), :continue, [])

      {:noreply,
       %{
         block_check_interval: block_check_interval,
         messenger_contract: env[:messenger_contract],
         json_rpc_named_arguments: json_rpc_named_arguments,
         end_block: safe_block,
         start_block: max(start_block, last_l1_block_number)
       }}
    else
      {:start_block_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        {:stop, :normal, %{}}

      {:rpc_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        {:stop, :normal, %{}}

      {:messenger_contract_address_is_valid, false} ->
        Logger.error("L1ScrollMessenger contract address is invalid or not defined.")
        {:stop, :normal, %{}}

      {:start_block_valid, false, last_l1_block_number, safe_block} ->
        Logger.error("Invalid L1 Start Block value. Please, check the value and scroll_bridge table.")
        Logger.error("last_l1_block_number = #{inspect(last_l1_block_number)}")
        Logger.error("safe_block = #{inspect(safe_block)}")
        {:stop, :normal, %{}}

      {:error, error_data} ->
        Logger.error(
          "Cannot get last L1 transaction from RPC by its hash, latest block, or block timestamp by its number due to RPC error: #{inspect(error_data)}"
        )

        {:stop, :normal, %{}}

      {:l1_transaction_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check scroll_bridge table."
        )

        {:stop, :normal, %{}}

      _ ->
        Logger.error("L1 Start Block is invalid or zero.")
        {:stop, :normal, %{}}
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
    Handles L1 block reorg: removes all Deposit rows from the `scroll_bridge` table
    created beginning from the reorged block.

    We only store block number for the initiating transaction of the L1->L2 or L2->L1 message,
    so the `block_number` column doesn't contain L2 block numbers for messages initiated on L1 layer (i.e. for Deposits),
    and that doesn't contain L1 block numbers for messages initiated on L2 layer (i.e. for Withdrawals).
    This is the reason why we can only remove rows for Deposit operations from the `scroll_bridge` table
    when a reorg happens on L1 layer.

    ## Parameters
    - `reorg_block`: The block number where reorg has occurred.

    ## Returns
    - Nothing.
  """
  @spec reorg_handle(non_neg_integer()) :: any()
  def reorg_handle(reorg_block) do
    {deleted_count, _} =
      Repo.delete_all(from(b in Bridge, where: b.type == :deposit and b.block_number >= ^reorg_block))

    if deleted_count > 0 do
      Logger.warning(
        "As L1 reorg was detected, some deposits with block_number >= #{reorg_block} were removed from scroll_bridge table. Number of removed rows: #{deleted_count}."
      )
    end
  end

  @doc """
    Returns L1 RPC URL for this module.
    Returns `nil` if not defined.
  """
  @spec l1_rpc_url() :: binary() | nil
  def l1_rpc_url do
    ScrollHelper.l1_rpc_url()
  end

  @doc """
    Determines if `Indexer.Fetcher.RollupL1ReorgMonitor` module must be up
    for this module.

    ## Returns
    - `true` if the reorg monitor must be active, `false` otherwise.
  """
  @spec requires_l1_reorg_monitor?() :: boolean()
  def requires_l1_reorg_monitor? do
    module_config = Application.get_all_env(:indexer)[__MODULE__]
    not is_nil(module_config[:start_block])
  end
end
