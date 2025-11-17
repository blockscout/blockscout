defmodule Indexer.Fetcher.Beacon.Deposit.Status do
  @moduledoc """
  Fetches the status of beacon deposits.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  alias Ecto.Multi
  alias Explorer.Chain.Beacon.Deposit
  alias Explorer.Chain.Beacon.Deposit.Pending, as: PendingDeposit
  alias Explorer.Chain.Wei
  alias Explorer.Repo
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
    {changes_list, max_block_timestamp} =
      pending_deposits
      |> Enum.reduce({[], DateTime.from_unix!(0)}, fn deposit, {acc, max_block_timestamp} ->
        {slot, ""} = Integer.parse(deposit["slot"])
        block_timestamp = slot |> slot_to_timestamp() |> DateTime.from_unix!()
        {amount, ""} = Integer.parse(deposit["amount"])

        {[
           PendingDeposit.changeset(%PendingDeposit{}, %{
             pubkey: deposit["pubkey"],
             withdrawal_credentials: deposit["withdrawal_credentials"],
             amount: amount |> Decimal.new() |> Wei.from(:gwei) |> Wei.to(:wei),
             signature: deposit["signature"],
             block_timestamp: block_timestamp
           }).changes
           | acc
         ], Enum.max([block_timestamp, max_block_timestamp], &DateTime.after?/2)}
      end)

    Multi.new()
    |> Multi.run(:create_temp_beacon_pending_deposits_table, fn repo, _changes ->
      repo.query("""
        CREATE TEMP TABLE temp_beacon_pending_deposits (
          pubkey bytea,
          withdrawal_credentials bytea,
          amount numeric,
          signature bytea,
          block_timestamp timestamp
        ) ON COMMIT DROP
      """)
    end)
    |> Multi.run(:insert_pending_deposits, fn repo, _changes ->
      {:ok, repo.safe_insert_all(PendingDeposit, changes_list, [])}
    end)
    |> Multi.update_all(
      :mark_completed_deposits,
      from(d in Deposit,
        as: :deposit,
        where: d.status == :pending,
        where: d.block_timestamp <= ^max_block_timestamp,
        where:
          not exists(
            from(pd in PendingDeposit,
              where: pd.pubkey == parent_as(:deposit).pubkey,
              where: pd.withdrawal_credentials == parent_as(:deposit).withdrawal_credentials,
              where: pd.amount == parent_as(:deposit).amount,
              where: pd.signature == parent_as(:deposit).signature,
              where: pd.block_timestamp == parent_as(:deposit).block_timestamp
            )
          )
      ),
      [set: [status: :completed, updated_at: DateTime.utc_now()]],
      timeout: :infinity
    )
    |> Repo.transaction()
  end

  defp slot_to_timestamp(slot) do
    config = Application.get_env(:indexer, Blob)
    slot_duration = config[:slot_duration]
    reference_slot = config[:reference_slot]
    reference_timestamp = config[:reference_timestamp]
    (slot - reference_slot) * slot_duration + reference_timestamp
  end
end
