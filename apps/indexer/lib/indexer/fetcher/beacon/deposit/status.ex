defmodule Indexer.Fetcher.Beacon.Deposit.Status do
  @moduledoc """
  Fetches the status of beacon deposits.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  alias Explorer.Chain.Beacon.Deposit
  alias Explorer.Chain.{Data, Wei}
  alias Explorer.{QueryHelper, Repo}
  alias Indexer.Fetcher.Beacon.{Blob, Client}

  def start_link(arguments, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, arguments, gen_server_options)
  end

  @impl GenServer
  def init(_state) do
    Logger.metadata(fetcher: :beacon_deposit_status)

    Process.send(self(), :fetch_queued_deposits, [])

    {:ok, nil}
  end

  @impl GenServer
  def handle_info(:fetch_queued_deposits, _state) do
    case Client.get_pending_deposits("head") do
      {:ok, %{"data" => pending_deposits}} -> mark_completed_deposits(pending_deposits)
      {:error, reason} -> Logger.error("Failed to fetch pending deposits: #{inspect(reason)}")
    end

    config = Application.get_env(:indexer, __MODULE__)
    epoch_duration = config[:epoch_duration]
    reference_timestamp = config[:reference_timestamp]

    current_time = System.os_time(:second)
    epochs_elapsed = div(current_time - reference_timestamp, epoch_duration)
    next_epoch_timestamp = (epochs_elapsed + 1) * epoch_duration + reference_timestamp

    timer =
      Process.send_after(
        self(),
        :fetch_queued_deposits,
        :timer.seconds(next_epoch_timestamp - current_time + 1)
      )

    {:noreply, timer}
  end

  defp mark_completed_deposits(pending_deposits) do
    ids =
      pending_deposits
      |> Enum.map(fn deposit ->
        {:ok, pubkey} = Data.cast(deposit["pubkey"])
        {:ok, withdrawal_credentials} = Data.cast(deposit["withdrawal_credentials"])
        {amount, ""} = Integer.parse(deposit["amount"])
        {:ok, signature} = Data.cast(deposit["signature"])
        {slot, ""} = Integer.parse(deposit["slot"])

        {pubkey.bytes, withdrawal_credentials.bytes, amount |> Decimal.new() |> Wei.from(:gwei) |> Wei.to(:wei),
         signature.bytes, slot |> slot_to_timestamp() |> DateTime.from_unix!()}
      end)

    tuple_not_in =
      dynamic(
        not (^QueryHelper.tuple_in([:pubkey, :withdrawal_credentials, :amount, :signature, :block_timestamp], ids))
      )

    batch_size = 100

    query =
      from(
        deposit in Deposit,
        where: deposit.status == :pending,
        where: ^tuple_not_in,
        select: deposit.index,
        order_by: [asc: deposit.index]
      )

    all_batch_ids =
      query
      |> Repo.all(timeout: :infinity)

    all_batch_ids
    |> Enum.chunk_every(batch_size)
    |> Enum.each(fn batch_ids ->
      Deposit
      |> where([deposit], deposit.index in ^batch_ids)
      |> Repo.update_all(set: [status: "completed", updated_at: DateTime.utc_now()])
    end)
  end

  defp slot_to_timestamp(slot) do
    config = Application.get_env(:indexer, Blob)
    slot_duration = config[:slot_duration]
    reference_slot = config[:reference_slot]
    reference_timestamp = config[:reference_timestamp]
    (slot - reference_slot) * slot_duration + reference_timestamp
  end
end
