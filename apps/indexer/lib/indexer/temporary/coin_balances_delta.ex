defmodule Indexer.Temporary.CoinBalancesDelta do
  @moduledoc """
  Computes the `delta` of `t:Explorer.Chain.Address.CoinBalance.t/0` that have a
  known `value` and saves the result in the database.

  This is meant to avoid having a long-running migration that adds all the `delta`s.
  """

  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.Wei
  alias Indexer.BufferedTask
  alias Indexer.Fetcher.CoinBalance, as: CoinBalanceFetcher

  @behaviour BufferedTask

  @defaults [
    flush_interval: :timer.seconds(3),
    max_batch_size: 100,
    max_concurrency: 1,
    task_supervisor: Indexer.Temporary.CoinBalancesDelta.TaskSupervisor,
    metadata: [fetcher: :coin_balances_delta],
    state: nil
  ]

  @doc false
  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec([init_options, gen_server_options]) when is_list(init_options) do
    merged_init_options = Keyword.merge(@defaults, init_options)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_options}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    query =
      from(cb in CoinBalance,
        where: not is_nil(cb.value),
        where: not is_nil(cb.value_fetched_at),
        where: is_nil(cb.delta) or is_nil(cb.delta_updated_at),
        order_by: [:address_hash, desc: :block_number],
        select: map(cb, [:address_hash, :block_number, :value, :value_fetched_at])
      )

    {:ok, final} = Repo.stream_reduce(query, initial, &reducer.(&1, &2))

    final
  end

  @impl BufferedTask
  def run(coin_balances_params, _) do
    importable_balances_params =
      coin_balances_params
      |> Enum.map(fn %{value: v, address_hash: h} = balance_params ->
        %{balance_params | value: Wei.to_integer(v), address_hash: to_string(h)}
      end)
      |> CoinBalanceFetcher.importable_balances_params()

    case Chain.import(%{address_coin_balances: %{params: importable_balances_params}}) do
      {:ok, _} ->
        :ok

      {:error, :timeout} ->
        Logger.error("failed to import address_coin_balances delta because of timeout")
        :retry

      {:error, changesets} ->
        Logger.error(fn -> ["failed to import: ", inspect(changesets)] end)
        :retry

      {:error, step, failed_value, _changes_so_far} ->
        Logger.error(fn -> ["failed to import: ", inspect(failed_value)] end, step: step)
        :retry
    end
  end
end
