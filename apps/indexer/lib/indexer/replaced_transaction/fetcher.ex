defmodule Indexer.ReplacedTransaction.Fetcher do
  @moduledoc """
  Finds and updates replaced transactions.
  """

  use Spandex.Decorators

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.Hash
  alias Indexer.{BufferedTask, Tracer}

  @behaviour BufferedTask

  @max_batch_size 10
  @max_concurrency 4
  @defaults [
    flush_interval: :timer.seconds(3),
    max_concurrency: @max_concurrency,
    max_batch_size: @max_batch_size,
    task_supervisor: Indexer.ReplacedTransaction.TaskSupervisor,
    metadata: [fetcher: :replaced_transaction]
  ]

  @spec async_fetch([
          %{
            required(:nonce) => non_neg_integer,
            required(:from_address_hash) => Hash.Address.t(),
            required(:block_hash) => Hash.Full.t()
          }
        ]) :: :ok
  def async_fetch(transactions_fields, timeout \\ 5000) when is_list(transactions_fields) do
    entries = Enum.map(transactions_fields, &entry/1)

    BufferedTask.buffer(__MODULE__, entries, timeout)
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    merged_init_opts =
      @defaults
      |> Keyword.merge(init_options)
      |> Keyword.put(:state, {})

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    {:ok, final} =
      Chain.stream_mined_transactions(
        [:block_hash, :nonce, :from_address_hash],
        initial,
        fn transaction_fields, acc ->
          transaction_fields
          |> entry()
          |> reducer.(acc)
        end
      )

    final
  end

  defp entry(%{
         block_hash: %Hash{bytes: block_hash_bytes},
         nonce: nonce,
         from_address_hash: %Hash{bytes: from_address_hash_bytes}
       })
       when is_integer(nonce) do
    {block_hash_bytes, nonce, from_address_hash_bytes}
  end

  defp params({block_hash_bytes, nonce, from_address_hash_bytes})
       when is_integer(nonce) do
    {:ok, from_address_hash} = Hash.Address.cast(from_address_hash_bytes)
    {:ok, block_hash} = Hash.Full.cast(block_hash_bytes)

    %{nonce: nonce, from_address_hash: from_address_hash, block_hash: block_hash}
  end

  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.ReplacedTransaction.Fetcher.run/2",
              service: :indexer,
              tracer: Tracer
            )
  def run(entries, _) do
    Logger.debug("fetching replaced transactions for transactions")

    try do
      {:ok, _} =
        entries
        |> Enum.map(&params/1)
        |> Chain.update_replaced_transactions()

      :ok
    rescue
      reason ->
        Logger.error(fn ->
          [
            "failed to update replaced transactions for transactions: ",
            inspect(reason)
          ]
        end)

        {:retry, entries}
    end
  end
end
