defmodule Indexer.TokenTransfers do
  @moduledoc """
  Process that inspects Log records for token transfers.
  """

  require Logger

  use GenServer

  alias Explorer.Chain
  alias Explorer.Chain.{Log, Token, TokenTransfer, Transaction}
  alias Explorer.Indexer.TokenTransfers.Queue

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    Chain.subscribe_to_events(:logs)

    send(self(), :fetch_uncataloged_token_transfers)
    send(self(), :catalog)

    state = %{catalog_task: nil, queue: Queue.new()}

    {:ok, state}
  end

  def handle_info(:fetch_uncataloged_token_transfers, %{queue: queue} = state) do
    Logger.debug(fn -> "Checking for uncataloged token transfers" end)

    queue = Queue.enqueue_list(queue, Chain.uncataloged_token_transfers())

    {:noreply, %{state | queue: queue}}
  end

  # Handles inserted logs coming from the main chain indexer process
  def handle_info({:chain_event, :logs, log_records}, %{queue: queue} = state) do
    token_transfer_logs =
      log_records
      |> Enum.filter(fn %Log{first_topic: topic} -> topic == TokenTransfer.constant() end)
      |> Chain.ensure_transaction_preloaded()

    queue = Queue.enqueue_list(queue, token_transfer_logs)

    {:noreply, %{state | queue: queue}}
  end

  def handle_info(:catalog, %{queue: queue} = state) do
    next_state =
      case Queue.dequeue(queue) do
        {:ok, {next_queue, item}} ->
          task = start_catalog_task(item)
          %{state | catalog_task: task, queue: next_queue}

        {:error, :empty} ->
          Process.send_after(self(), :catalog, 100)
          state
      end

    {:noreply, next_state}
  end

  # Successful catalog task message
  def handle_info({ref, {_item, {:ok, _}}}, state) when is_reference(ref) do
    Logger.debug(fn -> "successful catalog" end)

    next_state = %{state | catalog_task: nil}

    send(self(), :catalog)

    {:noreply, next_state}
  end

  # Failed catalog task message. Requeue item
  def handle_info({ref, {item, _}}, state) when is_reference(ref) do
    Logger.debug(fn -> "failed to catalog" end)
    next_queue = Queue.enqueue(state.queue, item)
    next_state = %{state | queue: next_queue, catalog_task: nil}

    send(self(), :catalog)

    {:noreply, next_state}
  end

  # Task process exited
  def handle_info({:DOWN, _ref, :process, _pid, _status}, state) do
    {:noreply, state}
  end

  defp start_catalog_task(item) do
    Task.Supervisor.async_nolink(Explorer.TaskSupervisor, fn -> {item, catalog(item)} end)
  end

  # Data coming from a chain event
  def catalog(%Log{} = log) do
    token = fetch_token(log)
    catalog(log, token)
  end

  # Data coming from checking uncataloged transfers
  def catalog(%{log: %Log{} = log, token: nil}) do
    token = fetch_token(log)
    catalog(log, token)
  end

  # Data coming from checking uncataloged transfers
  def catalog(%{log: %Log{} = log, token: %Token{} = token}) do
    catalog(log, token)
  end

  def catalog(%Log{} = log, %Token{} = token) do
    token_transfer_params = %{
      log_id: log.id,
      transaction_hash: log.transaction_hash,
      from_address_hash: truncate_hash(log.second_topic),
      to_address_hash: truncate_hash(log.third_topic),
      token_id: token.id,
      amount: convert_to_decimal(log.data)
    }

    {:ok, _} = Chain.import_token_transfer(token_transfer_params)
  end

  def fetch_token(%Log{transaction: %Transaction{} = transaction}) do
    with {:error, :not_found} <- Chain.token_by_hash(transaction.to_address_hash),
         # TODO
         # Run the functions on the smart contract for the `to_address` on the transaction.
         # The list of following functions are needed:
         # * totalSupply
         # * name
         # * decimals
         # * symbol
         # * owner
         #
         # Results from the call(s) need to be shaped to fit a Token and passed to the next function in the statement
         {:ok, %Token{} = token} <- Chain.import_token(%{}) do
      token
    else
      {:ok, token} ->
        token
    end
  end

  defp truncate_hash("0x00000000000000000000000" <> truncated_hash) do
    "0x#{truncated_hash}"
  end

  defp convert_to_decimal("0x" <> encoded_decimal) do
    encoded_decimal
    |> Base.decode16!()
    |> Decimal.new()
  end
end
