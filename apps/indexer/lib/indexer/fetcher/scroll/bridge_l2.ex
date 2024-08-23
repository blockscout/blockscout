defmodule Indexer.Fetcher.Scroll.BridgeL2 do
  @moduledoc """
  Fills scroll_bridge DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import Indexer.Fetcher.Scroll.Bridge,
    only: [get_logs_all: 3, import_operations: 1, prepare_operations: 3]

  alias Explorer.Chain.Scroll.{Bridge, Reader}
  alias Explorer.Repo
  alias Indexer.Helper

  @eth_get_logs_range_size 1000
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

  @impl GenServer
  def handle_info(:init_with_delay, %{json_rpc_named_arguments: json_rpc_named_arguments} = state) do
    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:messenger_contract_address_is_valid, true} <- {:messenger_contract_address_is_valid, Helper.address_correct?(env[:messenger_contract])},
         {last_l2_block_number, last_l2_transaction_hash} = Reader.last_l2_item(),
         {:ok, latest_block} = Helper.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000),
         {:ok, last_l2_tx} <- Helper.get_transaction_by_hash(last_l2_transaction_hash, json_rpc_named_arguments),
         {:l2_tx_not_found, false} <- {:l2_tx_not_found, !is_nil(last_l2_transaction_hash) && is_nil(last_l2_tx)} do
      Process.send(self(), :continue, [])

      {:noreply,
       %{
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
          "Cannot get last L2 transaction from RPC by its hash or latest block due to RPC error: #{inspect(error_data)}"
        )

        {:stop, :normal, state}

      {:l2_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L2 transaction from RPC by its hash. Probably, there was a reorg on L2 chain. Please, check scroll_bridge table."
        )

        {:stop, :normal, state}
    end
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          messenger_contract: messenger_contract,
          start_block: start_block,
          end_block: end_block,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    start_block..end_block
    |> Enum.chunk_every(@eth_get_logs_range_size)
    |> Enum.each(fn current_chunk ->
      chunk_start = List.first(current_chunk)
      chunk_end = List.last(current_chunk)

      if chunk_start <= chunk_end do
        Helper.log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, :L2)

        operations =
          {chunk_start, chunk_end}
          |> get_logs_all(messenger_contract, json_rpc_named_arguments)
          |> prepare_operations(false, json_rpc_named_arguments)

        import_operations(operations)

        Helper.log_blocks_chunk_handling(
          chunk_start,
          chunk_end,
          start_block,
          end_block,
          "#{Enum.count(operations)} L2 operation(s)",
          :L2
        )
      end
    end)

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  def reorg_handle(reorg_block) do
    {deleted_count, _} =
      Repo.delete_all(from(b in Bridge, where: b.type == :withdrawal and b.block_number >= ^reorg_block))

    if deleted_count > 0 do
      Logger.warning(
        "As L2 reorg was detected, some withdrawals with block_number >= #{reorg_block} were removed from scroll_bridge table. Number of removed rows: #{deleted_count}."
      )
    end
  end
end
