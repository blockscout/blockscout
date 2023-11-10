defmodule Indexer.Fetcher.RootstockData do
  @moduledoc """
  Refetch `minimum_gas_price`, `bitcoin_merged_mining_header`, `bitcoin_merged_mining_coinbase_transaction`,
  `bitcoin_merged_mining_merkle_proof`, `hash_for_merged_mining` fields for blocks that were indexed before app update.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  alias EthereumJSONRPC.Blocks
  alias Explorer.Chain.Block
  alias Explorer.Repo

  @interval :timer.seconds(3)
  @batch_size 10
  @concurrency 5
  @db_batch_size 300

  defstruct blocks_to_fetch: [],
            interval: @interval,
            json_rpc_named_arguments: [],
            batch_size: @batch_size,
            max_concurrency: @concurrency,
            db_batch_size: @db_batch_size

  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
    default = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments}
    }

    Supervisor.child_spec(default, restart: :transient)
  end

  def start_link(arguments, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, arguments, gen_server_options)
  end

  @impl GenServer
  def init(opts) when is_list(opts) do
    Logger.metadata(fetcher: :rootstock_data)

    json_rpc_named_arguments = opts[:json_rpc_named_arguments]

    unless json_rpc_named_arguments do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.init to allow for json_rpc calls when running."
    end

    state = %__MODULE__{
      blocks_to_fetch: nil,
      interval: opts[:interval] || Application.get_env(:indexer, __MODULE__)[:interval],
      json_rpc_named_arguments: json_rpc_named_arguments,
      batch_size: opts[:batch_size] || Application.get_env(:indexer, __MODULE__)[:batch_size],
      max_concurrency: opts[:max_concurrency] || Application.get_env(:indexer, __MODULE__)[:max_concurrency],
      db_batch_size: opts[:db_batch_size] || Application.get_env(:indexer, __MODULE__)[:db_batch_size]
    }

    Process.send_after(self(), :fetch_rootstock_data, state.interval)

    {:ok, state, {:continue, :fetch_blocks}}
  end

  @impl GenServer
  def handle_continue(:fetch_blocks, state), do: fetch_blocks(state)

  @impl GenServer
  def handle_info(:fetch_blocks, state), do: fetch_blocks(state)

  @impl GenServer
  def handle_info(
        :fetch_rootstock_data,
        %__MODULE__{
          blocks_to_fetch: blocks_to_fetch,
          interval: interval,
          json_rpc_named_arguments: json_rpc_named_arguments,
          batch_size: batch_size,
          max_concurrency: concurrency
        } = state
      ) do
    if Enum.empty?(blocks_to_fetch) do
      send(self(), :fetch_blocks)
      {:noreply, state}
    else
      new_blocks_to_fetch =
        blocks_to_fetch
        |> Stream.chunk_every(batch_size)
        |> Task.async_stream(
          &{EthereumJSONRPC.fetch_blocks_by_numbers(
             Enum.map(&1, fn b -> b.number end),
             json_rpc_named_arguments,
             false
           ), &1},
          max_concurrency: concurrency,
          timeout: :infinity,
          zip_input_on_exit: true
        )
        |> Enum.reduce([], &fetch_reducer/2)

      Process.send_after(self(), :fetch_rootstock_data, interval)

      {:noreply, %__MODULE__{state | blocks_to_fetch: new_blocks_to_fetch}}
    end
  end

  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  def handle_info(
        {:DOWN, _ref, :process, _pid, reason},
        state
      ) do
    if reason === :normal do
      {:noreply, state}
    else
      Logger.error(fn -> "Rootstock data fetcher task exited due to #{inspect(reason)}." end)
      {:noreply, state}
    end
  end

  defp fetch_blocks(%__MODULE__{db_batch_size: db_batch_size, interval: interval} = state) do
    blocks_to_fetch = db_batch_size |> Block.blocks_without_rootstock_data_query() |> Repo.all()

    if Enum.empty?(blocks_to_fetch) do
      Logger.info("Rootstock data from old blocks are fetched.")

      {:stop, :normal, state}
    else
      [%Block{number: max_number} | _] = blocks_to_fetch

      Logger.info(
        "Rootstock data will now be fetched for #{Enum.count(blocks_to_fetch)} blocks starting from #{max_number}."
      )

      Process.send_after(self(), :fetch_rootstock_data, interval)

      {:noreply, %__MODULE__{state | blocks_to_fetch: blocks_to_fetch}}
    end
  end

  defp fetch_reducer({:ok, {{:ok, %Blocks{blocks_params: block_params}}, blocks}}, acc) do
    blocks_map = Map.new(blocks, fn b -> {b.number, b} end)

    for block_param <- block_params,
        block = blocks_map[block_param.number],
        block_param.hash == to_string(block.hash) do
      block |> Block.changeset(block_param) |> Repo.update()
    end

    acc
  end

  defp fetch_reducer({:ok, {{:error, reason}, blocks}}, acc) do
    Logger.error("failed to fetch: " <> inspect(reason) <> ". Retrying.")
    [blocks | acc] |> List.flatten()
  end

  defp fetch_reducer({:exit, {blocks, reason}}, acc) do
    Logger.error("failed to fetch: " <> inspect(reason) <> ". Retrying.")
    [blocks | acc] |> List.flatten()
  end
end
