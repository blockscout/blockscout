defmodule Indexer.Fetcher.Arbitrum.MessagesToL2Matcher do
  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1]

  require Logger

  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Arbitrum.MessagesToL2Matcher.Supervisor, as: MessagesToL2MatcherSupervisor

  @behaviour BufferedTask

  @default_max_batch_size 1
  @default_max_concurrency 10

  def child_spec([init_options, gen_server_options]) do
    buffered_task_init_options =
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.merge(state: %{})

    Supervisor.child_spec({BufferedTask, [{__MODULE__, buffered_task_init_options}, gen_server_options]},
      id: __MODULE__
    )
  end

  @impl BufferedTask
  def init(initial, _, _) do
    initial
  end

  @impl BufferedTask
  def run(txs, _) when is_list(txs) do
    txs
    |> Enum.each(fn tx ->
      log_info("Attempting to decode the requist id #{tx.request_id} to L1-to-L2 message id")
    end)
  end

  def async_discover_match(txs_with_messages_from_l1) do
    if MessagesToL2MatcherSupervisor.disabled?() do
      :ok
    else
      BufferedTask.buffer(__MODULE__, txs_with_messages_from_l1, false)
    end
  end

  defp defaults do
    [
      flush_interval: :timer.seconds(1),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      poll: false,
      task_supervisor: __MODULE__.TaskSupervisor,
      metadata: [fetcher: :messages_to_l2_matcher]
    ]
  end
end
