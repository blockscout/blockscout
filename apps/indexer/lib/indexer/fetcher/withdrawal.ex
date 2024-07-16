defmodule Indexer.Fetcher.Withdrawal do
  @moduledoc """
  Reindexes withdrawals from blocks that were indexed before app update.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  alias EthereumJSONRPC.Blocks
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Withdrawal
  alias Explorer.Helper
  alias Indexer.Transform.Addresses

  @interval :timer.seconds(10)
  @batch_size 10
  @concurrency 5

  defstruct blocks_to_fetch: [],
            interval: @interval,
            json_rpc_named_arguments: [],
            max_batch_size: @batch_size,
            max_concurrency: @concurrency

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
    Logger.metadata(fetcher: :withdrawal)
    first_block = Application.get_env(:indexer, __MODULE__)[:first_block]

    if first_block |> Helper.parse_integer() |> is_integer() do
      # withdrawals from all other blocks will be imported by realtime and catchup indexers
      json_rpc_named_arguments = opts[:json_rpc_named_arguments]

      unless json_rpc_named_arguments do
        raise ArgumentError,
              ":json_rpc_named_arguments must be provided to `#{__MODULE__}.init to allow for json_rpc calls when running."
      end

      state = %__MODULE__{
        interval: opts[:interval] || @interval,
        json_rpc_named_arguments: json_rpc_named_arguments,
        max_batch_size: opts[:max_batch_size] || @batch_size,
        max_concurrency: opts[:max_concurrency] || @concurrency
      }

      Process.send_after(self(), :fetch_withdrawals, state.interval)

      {:ok, state, {:continue, first_block}}
    else
      Logger.warning("Please, specify the first block of the block range for #{__MODULE__}.")
      :ignore
    end
  end

  @impl GenServer
  def handle_continue(first_block, state) do
    {:noreply, %{state | blocks_to_fetch: first_block |> Helper.parse_integer() |> missing_block_numbers()}}
  end

  @impl GenServer
  def handle_info(
        :fetch_withdrawals,
        %__MODULE__{
          blocks_to_fetch: blocks_to_fetch,
          interval: interval,
          json_rpc_named_arguments: json_rpc_named_arguments,
          max_batch_size: batch_size,
          max_concurrency: concurrency
        } = state
      ) do
    Logger.metadata(fetcher: :withdrawal)

    if Enum.empty?(blocks_to_fetch) do
      Logger.info("Withdrawals from old blocks are fetched.")
      {:stop, :normal, state}
    else
      new_blocks_to_fetch =
        blocks_to_fetch
        |> Stream.chunk_every(batch_size)
        |> Task.async_stream(
          &{EthereumJSONRPC.fetch_blocks_by_numbers(&1, json_rpc_named_arguments), &1},
          max_concurrency: concurrency,
          timeout: :infinity,
          zip_input_on_exit: true
        )
        |> Enum.reduce([], &fetch_reducer/2)

      Process.send_after(self(), :fetch_withdrawals, interval)

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
      Logger.metadata(fetcher: :withdrawal)
      Logger.error(fn -> "Withdrawals fetcher task exited due to #{inspect(reason)}." end)
      {:noreply, state}
    end
  end

  defp fetch_reducer({:ok, {{:ok, %Blocks{withdrawals_params: withdrawals_params}}, block_numbers}}, acc) do
    addresses = Addresses.extract_addresses(%{withdrawals: withdrawals_params})

    case Chain.import(%{addresses: %{params: addresses}, withdrawals: %{params: withdrawals_params}}) do
      {:ok, _} ->
        acc

      {:error, reason} ->
        Logger.error(inspect(reason) <> ". Retrying.")
        [block_numbers | acc] |> List.flatten()

      {:error, step, failed_value, _changes_so_far} ->
        Logger.error("failed to insert: " <> inspect(failed_value) <> ". Retrying.", step: step)
        [block_numbers | acc] |> List.flatten()
    end
  end

  defp fetch_reducer({:ok, {{:error, reason}, block_numbers}}, acc) do
    Logger.error("failed to fetch: " <> inspect(reason) <> ". Retrying.")
    [block_numbers | acc] |> List.flatten()
  end

  defp fetch_reducer({:exit, {block_numbers, reason}}, acc) do
    Logger.error("failed to fetch: " <> inspect(reason) <> ". Retrying.")
    [block_numbers | acc] |> List.flatten()
  end

  defp missing_block_numbers(from) do
    blocks = from |> Withdrawal.blocks_without_withdrawals_query() |> Repo.all()
    Logger.debug("missing_block_numbers #{length(blocks)}")
    blocks
  end
end
