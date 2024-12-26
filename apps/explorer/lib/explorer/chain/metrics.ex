defmodule Explorer.Chain.Metrics do
  @moduledoc """
  Module responsible for periodically setting current chain metrics.
  """

  use GenServer

  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Chain.Metrics.Queries
  alias Explorer.Prometheus.Instrumenter

  @interval :timer.hours(1)
  @options [timeout: 60_000, api?: true]
  @metrics_list [
    :success_transactions_number,
    :deployed_smart_contracts_number,
    :verified_smart_contracts_number,
    :new_addresses_number,
    :new_tokens_number,
    :new_token_transfers_number,
    :simplified_active_addresses_number
  ]

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    if Application.get_env(:explorer, __MODULE__)[:enabled] do
      send(self(), :set_metrics)
      {:ok, %{}}
    else
      :ignore
    end
  end

  def handle_info(:set_metrics, state) do
    schedule_next_run()
    set_metrics()

    {:noreply, state}
  end

  defp set_metrics do
    @metrics_list
    |> Enum.map(fn metric ->
      Task.async(fn ->
        set_handler_metric(metric)
      end)
    end)
    |> Task.yield_many(:timer.hours(1))
    |> Enum.map(fn {_task, res} ->
      case res do
        {:ok, result} ->
          result

        {:exit, reason} ->
          raise "Query fetching explorer & chain metrics terminated: #{inspect(reason)}"

        nil ->
          raise "Query fetching explorer & chain metrics timed out."
      end
    end)
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp set_handler_metric(metric) do
    func = String.to_atom(to_string(metric) <> "_query")

    transactions_count =
      Queries
      |> apply(func, [])
      |> select_repo(@options).one()

    apply(Instrumenter, metric, [transactions_count])
  end

  defp schedule_next_run do
    Process.send_after(self(), :set_metrics, @interval)
  end
end
