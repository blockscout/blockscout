defmodule Indexer.TokenTransferBlockConsensusSanitizer do
  @moduledoc """
  Periodically find token transfers with incorrect block_consensus and set refetch_needed for their blocks.
  """

  use GenServer

  require Logger

  import Ecto.Query

  alias Explorer.Chain.{Block, TokenTransfer}
  alias Explorer.Repo

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent,
      shutdown: Application.get_env(:indexer, :graceful_shutdown_period)
    }
  end

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    schedule_sanitize()

    {:ok, %{}}
  end

  def handle_info(:sanitize, state) do
    block_numbers =
      TokenTransfer
      |> join(:inner, [tt], b in assoc(tt, :block))
      |> where([tt, b], tt.block_consensus != b.consensus)
      |> select([tt], tt.block_number)
      |> distinct(true)
      |> Repo.all(timeout: :infinity)

    case block_numbers do
      [] ->
        Logger.debug("[TokenTransferBlockConsensusSanitizer] No inconsistent token transfer block consensus found")

      numbers ->
        Logger.info("[TokenTransferBlockConsensusSanitizer] Marking #{length(numbers)} blocks for refetch")
        Block.set_refetch_needed(numbers)
    end

    schedule_sanitize()

    {:noreply, state}
  end

  defp schedule_sanitize do
    Process.send_after(self(), :sanitize, Application.get_env(:indexer, __MODULE__)[:interval])
  end
end
