defmodule Explorer.Celo.RebuildAttestationStats do
  @moduledoc """
    A task to calculate attestation stats for each CeloAccount and update each row in the database.

    Note: This query is very expensive and should not be needed under normal usage, as the values are calculated
  incrementally upon processing of each event.
  """
  alias Explorer.Repo
  require Explorer.Celo.Telemetry, as: Telemetry
  require Logger

  use Explorer.Celo.EventTypes

  def run(timeout) do
    {:ok, pid} = Task.Supervisor.start_link()

    stats =
      Task.Supervisor.async(pid, fn ->
        Telemetry.wrap(:rebuild_attestation_stats, fn ->
          rebuild_attestation_stats(timeout)
        end)
      end)

    Task.await(stats)
  end

  def rebuild_attestation_stats(timeout) do
    query = """
      update celo_account
      set attestations_requested = stats.requested, attestations_fulfilled = stats.fulfilled
      from (
          select r.address, r.requested, f.fulfilled
          from (
              select celo_account.address, count(*) as requested
              from logs, celo_account
              where logs.first_topic='#{@attestation_issuer_selected}'
              and logs.fourth_topic='0x000000000000000000000000'||encode(celo_account.address::bytea, 'hex') group by address
          ) r
          inner join (
              select address, count(*) as fulfilled
              from logs, celo_account
              where first_topic='#{@attestation_completed}'
              and fourth_topic='0x000000000000000000000000'||encode(address::bytea, 'hex') group by address
          ) f
          on r.address = f.address
      ) stats
      where celo_account.address = stats.address;
    """

    Repo.query!(query, [], timeout: timeout)
  end
end
