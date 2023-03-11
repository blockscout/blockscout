defmodule Indexer.Fetcher.OptimismDeposit do
  @moduledoc """
  Fills op_deposits DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Explorer.Helpers, only: [decode_data: 2]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.OptimismDeposit
  alias Indexer.Fetcher.Optimism
  alias Indexer.Helpers

  defstruct [
    :batch_size,
    :start_block,
    :safe_block,
    :optimism_portal,
    :json_rpc_named_arguments,
    mode: :catch_up,
    filter_id: nil,
    check_interval: nil
  ]

  # 32-byte signature of the event TransactionDeposited(address indexed from, address indexed to, uint256 indexed version, bytes opaqueData)
  @transaction_deposited_event "0xb3813568d9991fc951961fcb4c784893574240a28925604d09fc577c55bb7c32"
  @retry_interval_minutes 3
  @retry_interval :timer.minutes(@retry_interval_minutes)
  @address_prefix "0x000000000000000000000000"
  @batch_size 500

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
    Logger.metadata(fetcher: :optimism_deposits)

    env = Application.get_all_env(:indexer)[__MODULE__]
    optimism_portal = Application.get_env(:indexer, :optimism_l1_portal)
    optimism_rpc_l1 = Application.get_env(:indexer, :optimism_l1_rpc)

    with {:start_block_l1_undefined, false} <- {:start_block_l1_undefined, is_nil(env[:start_block_l1])},
         {:optimism_portal_valid, true} <- {:optimism_portal_valid, Helpers.is_address_correct?(optimism_portal)},
         {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(optimism_rpc_l1)},
         start_block_l1 <- Optimism.parse_integer(env[:start_block_l1]),
         false <- is_nil(start_block_l1),
         true <- start_block_l1 > 0,
         {last_l1_block_number, last_l1_tx_hash} <- get_last_l1_item(),
         json_rpc_named_arguments = Optimism.json_rpc_named_arguments(optimism_rpc_l1),
         {:ok, last_l1_tx} <- Optimism.get_transaction_by_hash(last_l1_tx_hash, json_rpc_named_arguments),
         {:l1_tx_not_found, false} <- {:l1_tx_not_found, !is_nil(last_l1_tx_hash) && is_nil(last_l1_tx)},
         {:ok, safe_block} <- Optimism.get_block_number_by_tag("safe", json_rpc_named_arguments),
         {:start_block_l1_valid, true} <-
           {:start_block_l1_valid,
            (start_block_l1 <= last_l1_block_number || last_l1_block_number == 0) && start_block_l1 <= safe_block} do
      Process.send(self(), :fetch, [])

      {:ok,
       %__MODULE__{
         start_block: max(start_block_l1, last_l1_block_number),
         safe_block: safe_block,
         optimism_portal: optimism_portal,
         json_rpc_named_arguments: json_rpc_named_arguments,
         batch_size: Optimism.parse_integer(env[:batch_size]) || @batch_size
       }}
    else
      {:start_block_l1_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        :ignore

      {:start_block_l1_valid, false} ->
        Logger.error("Invalid L1 Start Block value. Please, check the value and op_deposits table.")
        :ignore

      {:rpc_l1_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        :ignore

      {:optimism_portal_valid, false} ->
        Logger.error("OptimismPortal contract address is invalid or undefined.")
        :ignore

      {:error, error_data} ->
        Logger.error(
          "Cannot get last L1 transaction from RPC by its hash or last safe block due to the RPC error: #{inspect(error_data)}"
        )

        :ignore

      {:l1_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check op_deposits table."
        )

        :ignore

      _ ->
        Logger.error("Optimism deposits L1 Start Block is invalid or zero.")
        :ignore
    end
  end

  @impl GenServer
  def handle_info(
        :fetch,
        %__MODULE__{
          start_block: start_block,
          safe_block: safe_block,
          optimism_portal: optimism_portal,
          json_rpc_named_arguments: json_rpc_named_arguments,
          mode: :catch_up,
          batch_size: batch_size
        } = state
      ) do
    Logger.metadata(fetcher: :optimism_deposits)
    to_block = min(start_block + batch_size, safe_block)

    with {:logs, {:ok, logs}} <-
           {:logs,
            Optimism.get_logs(
              start_block,
              to_block,
              optimism_portal,
              @transaction_deposited_event,
              json_rpc_named_arguments,
              3
            )},
         deposits = events_to_deposits(logs, json_rpc_named_arguments),
         {:import, {:ok, _imported}} <-
           {:import, Chain.import(%{optimism_deposits: %{params: deposits}, timeout: :infinity})} do
      if to_block == safe_block do
        Process.send(self(), :switch_to_realtime, [])
        {:noreply, state}
      else
        Process.send(self(), :fetch, [])
        {:noreply, %{state | start_block: to_block + 1}}
      end
    else
      {:logs, {:error, _error}} ->
        Logger.error("Cannot fetch logs. Retrying in #{@retry_interval_minutes} minutes...")
        Process.send_after(self(), :fetch, @retry_interval)
        {:noreply, state}

      {:import, {:error, error}} ->
        Logger.error("Cannot import logs due to #{inspect(error)}. Retrying in #{@retry_interval_minutes} minutes...")
        Process.send_after(self(), :fetch, @retry_interval)
        {:noreply, state}

      {:import, {:error, step, failed_value, _changes_so_far}} ->
        Logger.error(
          "Failed to import #{inspect(failed_value)} during #{step}. Retrying in #{@retry_interval_minutes} minutes..."
        )

        Process.send_after(self(), :fetch, @retry_interval)
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(
        :switch_to_realtime,
        %__MODULE__{
          safe_block: safe_block,
          optimism_portal: optimism_portal,
          json_rpc_named_arguments: json_rpc_named_arguments,
          mode: :catch_up
        } = state
      ) do
    Logger.metadata(fetcher: :optimism_deposits)

    with {:ok, filter_id} <-
           Optimism.get_new_filter(
             safe_block + 1,
             "latest",
             optimism_portal,
             @transaction_deposited_event,
             json_rpc_named_arguments
           ),
         {:timestamp, {:ok, safe_block_timestamp}} <-
           {:timestamp, Optimism.get_block_timestamp_by_number(safe_block, json_rpc_named_arguments)},
         {:timestamp, {:ok, prev_safe_block_timestamp}} <-
           {:timestamp, Optimism.get_block_timestamp_by_number(safe_block - 1, json_rpc_named_arguments)} do
      check_interval = ceil((safe_block_timestamp - prev_safe_block_timestamp) * 1000 / 2)
      Process.send(self(), :fetch, [])
      {:noreply, %{state | mode: :realtime, filter_id: filter_id, check_interval: check_interval}}
    else
      {:error, _error} ->
        Logger.error("Failed to set logs filter. Retrying in #{@retry_interval_minutes} minutes...")
        Process.send_after(self(), :switch_to_realtime, @retry_interval)
        {:noreply, state}

      {:timestamp, {:error, _error}} ->
        Logger.error(
          "Failed to get timestamp of a block for check_interval calculation. Retrying in #{@retry_interval_minutes} minutes..."
        )

        Process.send_after(self(), :switch_to_realtime, @retry_interval)
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(
        :fetch,
        %__MODULE__{
          json_rpc_named_arguments: json_rpc_named_arguments,
          mode: :realtime,
          filter_id: filter_id,
          check_interval: check_interval
        } = state
      ) do
    Logger.metadata(fetcher: :optimism_deposits)

    case Optimism.get_filter_changes(filter_id, json_rpc_named_arguments) do
      {:ok, logs} ->
        handle_new_logs(logs, json_rpc_named_arguments)
        Process.send_after(self(), :fetch, check_interval)
        {:noreply, state}

      {:error, :filter_not_found} ->
        Logger.error("The old filter not found on the node. Creating new filter...")
        Process.send(self(), :update_filter, [])
        {:noreply, state}

      {:error, _error} ->
        Logger.error("Failed to set logs filter. Retrying in #{@retry_interval_minutes} minutes...")
        Process.send_after(self(), :fetch, @retry_interval)
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(
        :update_filter,
        %__MODULE__{
          optimism_portal: optimism_portal,
          json_rpc_named_arguments: json_rpc_named_arguments,
          mode: :realtime
        } = state
      ) do
    Logger.metadata(fetcher: :optimism_deposits)
    {last_l1_block_number, _} = get_last_l1_item()

    case Optimism.get_new_filter(
           last_l1_block_number + 1,
           "latest",
           optimism_portal,
           @transaction_deposited_event,
           json_rpc_named_arguments
         ) do
      {:ok, filter_id} ->
        Process.send(self(), :fetch, [])
        {:noreply, %{state | filter_id: filter_id}}

      {:error, _error} ->
        Logger.error("Failed to set logs filter. Retrying in #{@retry_interval_minutes} minutes...")
        Process.send_after(self(), :update_filter, @retry_interval)
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @impl GenServer
  def terminate(
        _reason,
        %__MODULE__{
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    Logger.metadata(fetcher: :optimism_deposits)

    if state.filter_id do
      Logger.info("Optimism deposits fetcher is terminating, uninstalling filter")
      Optimism.uninstall_filter(state.filter_id, json_rpc_named_arguments)
    end
  end

  defp handle_new_logs(logs, json_rpc_named_arguments) do
    {reorgs, logs_to_parse} =
      logs
      |> Enum.reduce({MapSet.new(), []}, fn
        %{"removed" => true, "blockNumber" => block_number}, {reorgs, logs_to_parse} ->
          {MapSet.put(reorgs, block_number), logs_to_parse}

        log, {reorgs, logs_to_parse} ->
          {reorgs, [log | logs_to_parse]}
      end)

    handle_reorgs(reorgs)

    deposits = events_to_deposits(logs_to_parse, json_rpc_named_arguments)
    {:ok, _imported} = Chain.import(%{optimism_deposits: %{params: deposits}, timeout: :infinity})
  end

  defp events_to_deposits(logs, json_rpc_named_arguments) do
    Logger.metadata(fetcher: :optimism_deposits)

    timestamps =
      logs
      |> Enum.reduce(MapSet.new(), fn %{"blockNumber" => block_number_quantity}, acc ->
        block_number = quantity_to_integer(block_number_quantity)
        MapSet.put(acc, block_number)
      end)
      |> MapSet.to_list()
      |> Optimism.get_block_timestamps_by_numbers(json_rpc_named_arguments)
      |> case do
        {:ok, timestamps} ->
          timestamps

        {:error, error} ->
          Logger.error(
            "Failed to get L1 block timestamps for deposits due to #{inspect(error)}. Timestamps will be set to now."
          )

          %{}
      end

    Enum.map(logs, &event_to_deposit(&1, timestamps))
  end

  defp event_to_deposit(
         %{
           "blockHash" => "0x" <> stripped_block_hash,
           "blockNumber" => block_number_quantity,
           "transactionHash" => transaction_hash,
           "logIndex" => "0x" <> stripped_log_index,
           "topics" => [_, @address_prefix <> from_stripped, @address_prefix <> to_stripped, _],
           "data" => opaque_data
         },
         timestamps
       ) do
    {_, prefixed_block_hash} = (String.pad_leading("", 64, "0") <> stripped_block_hash) |> String.split_at(-64)
    {_, prefixed_log_index} = (String.pad_leading("", 64, "0") <> stripped_log_index) |> String.split_at(-64)

    deposit_id_hash =
      "#{prefixed_block_hash}#{prefixed_log_index}"
      |> Base.decode16!(case: :mixed)
      |> ExKeccak.hash_256()
      |> Base.encode16(case: :lower)

    source_hash =
      "#{String.pad_leading("", 64, "0")}#{deposit_id_hash}"
      |> Base.decode16!(case: :mixed)
      |> ExKeccak.hash_256()

    [
      <<
        msg_value::binary-size(32),
        value::binary-size(32),
        gas_limit::binary-size(8),
        is_creation::binary-size(1),
        data::binary
      >>
    ] = decode_data(opaque_data, [:bytes])

    rlp_encoded =
      ExRLP.encode(
        [
          source_hash,
          from_stripped |> Base.decode16!(case: :mixed),
          to_stripped |> Base.decode16!(case: :mixed),
          msg_value |> String.replace_leading(<<0>>, <<>>),
          value |> String.replace_leading(<<0>>, <<>>),
          gas_limit |> String.replace_leading(<<0>>, <<>>),
          is_creation |> String.replace_leading(<<0>>, <<>>),
          data
        ],
        encoding: :hex
      )

    l2_tx_hash =
      "0x" <> ("7e#{rlp_encoded}" |> Base.decode16!(case: :mixed) |> ExKeccak.hash_256() |> Base.encode16(case: :lower))

    block_number = quantity_to_integer(block_number_quantity)

    %{
      l1_block_number: block_number,
      l1_block_timestamp: Map.get_lazy(timestamps, block_number, &DateTime.utc_now/0),
      l1_transaction_hash: transaction_hash,
      l1_transaction_origin: "0x" <> from_stripped,
      l2_transaction_hash: l2_tx_hash
    }
  end

  defp handle_reorgs(reorgs) do
    Logger.metadata(fetcher: :optimism_deposits)

    if MapSet.size(reorgs) > 0 do
      {deleted_count, _} = Repo.delete_all(from(d in OptimismDeposit, where: d.l1_block_number in ^reorgs))

      if deleted_count > 0 do
        Logger.warning(
          "As L1 reorg was detected, all affected rows were removed from the op_deposits table. Number of removed rows: #{deleted_count}."
        )
      end
    end
  end

  defp get_last_l1_item do
    OptimismDeposit.last_deposit_l1_block_number_query()
    |> Repo.one()
    |> Kernel.||({0, nil})
  end
end
