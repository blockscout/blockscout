defmodule Explorer.Chain.Metrics do
  @moduledoc """
  Module responsible for periodically setting current chain metrics.
  """

  use GenServer

  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Chain.Metrics.Queries
  alias Explorer.Prometheus.Instrumenter

  @interval :timer.hours(1)
  @options [timeout: :infinity]

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    send(self(), :set_metrics)

    {:ok, %{}}
  end

  def handle_info(:set_metrics, state) do
    set_metrics()
    schedule_next_run()

    {:noreply, state}
  end

  defp set_metrics do
    set_handler_metric(:weekly_success_transactions_number)
    set_handler_metric(:weekly_deployed_smart_contracts_number)
    set_handler_metric(:weekly_verified_smart_contracts_number)
    set_handler_metric(:weekly_new_wallet_addresses_number)
    set_handler_metric(:weekly_new_tokens_number)
    set_handler_metric(:weekly_new_token_transfers_number)
    set_handler_metric(:weekly_active_addresses_number)
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp set_handler_metric(metric) do
    func = String.to_atom(to_string(metric) <> "_query")

    weekly_transactions_count =
      Queries
      |> apply(func, [])
      |> select_repo(@options).one()

    apply(Instrumenter, metric, [weekly_transactions_count])
  end

  defp schedule_next_run do
    Process.send_after(self(), :set_metrics, @interval)
  end
end
