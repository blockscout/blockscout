# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.TokenTransferPoisoning do
  @moduledoc """
  Scores freshly imported token transfers as address poisoning attacks and
  records the ones that qualify.

  Fed by the block fetchers after every import, realtime and catch-up alike;
  there is no backfill of what was indexed before the fetcher was enabled.
  The scoring itself lives in `Explorer.Chain.TokenTransfer.PoisoningAttack.Detector`;
  this module only decides what to hand it — the fungible transfers of the
  batch, each with the sender of its transaction and the fan-out of that
  sender within the batch — and persists the verdicts.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  require Logger

  alias Explorer.Chain.{Hash, TokenTransfer, Transaction}
  alias Explorer.Chain.TokenTransfer.PoisoningAttack
  alias Explorer.Chain.TokenTransfer.PoisoningAttack.{Actions, Config, Detector, Result}
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Fetcher.TokenTransferPoisoning.Supervisor, as: TokenTransferPoisoningSupervisor

  @behaviour BufferedTask

  @default_max_batch_size 10
  @default_max_concurrency 2

  # What the detector reads off a transfer; the rest of the imported struct is
  # dropped before buffering so the queue holds no associations
  @entry_fields ~w(from_address_hash to_address_hash token_contract_address_hash amount amounts token_ids token_type block_hash block_number log_index transaction_hash)a

  @doc """
  Buffers the scorable transfers of an import batch for detection.

  `transactions` are the transactions imported along with the transfers, used
  to find who sent each transfer and how many addresses each sender touched.
  """
  @spec async_fetch([TokenTransfer.t()], [Transaction.t()], boolean(), timeout()) :: :ok
  def async_fetch(token_transfers, transactions, realtime?, timeout \\ 5000) when is_list(token_transfers) do
    if TokenTransferPoisoningSupervisor.disabled?() do
      :ok
    else
      case entries(token_transfers, transactions) do
        [] -> :ok
        entries -> BufferedTask.buffer(__MODULE__, entries, realtime?, timeout)
      end
    end
  end

  @doc """
  Turns an import batch into detector entries: one per transfer of a token
  type the detection applies to, carrying the sender and the recipient of its
  transaction and the sender's fan-out — the number of distinct addresses the
  sender's transfers touched within the batch.
  """
  @spec entries([TokenTransfer.t()], [Transaction.t()]) :: [Detector.entry()]
  def entries(token_transfers, transactions) do
    token_types = Config.load().token_types

    transactions_by_hash =
      Map.new(transactions, fn transaction ->
        {transaction.hash, {transaction.from_address_hash, transaction.to_address_hash}}
      end)

    scorable = Enum.filter(token_transfers, &scorable?(&1, token_types))
    fanout = fanout(scorable, transactions_by_hash)

    Enum.map(scorable, fn token_transfer ->
      {issuer, transaction_to} = Map.get(transactions_by_hash, token_transfer.transaction_hash, {nil, nil})

      %{
        token_transfer: struct(TokenTransfer, Map.take(token_transfer, @entry_fields)),
        issuer: issuer,
        transaction_to: transaction_to,
        fanout: Map.get(fanout, issuer, 0)
      }
    end)
  end

  defp scorable?(%TokenTransfer{token_type: token_type}, token_types) when is_binary(token_type) do
    String.upcase(token_type) in token_types
  end

  defp scorable?(_token_transfer, _token_types), do: false

  defp fanout(token_transfers, transactions_by_hash) do
    token_transfers
    |> Enum.reduce(%{}, fn token_transfer, acc ->
      case Map.get(transactions_by_hash, token_transfer.transaction_hash) do
        {%Hash{} = issuer, _to} ->
          Map.update(
            acc,
            issuer,
            MapSet.new([token_transfer.from_address_hash, token_transfer.to_address_hash]),
            &(&1 |> MapSet.put(token_transfer.from_address_hash) |> MapSet.put(token_transfer.to_address_hash))
          )

        _ ->
          acc
      end
    end)
    |> Map.new(fn {issuer, participants} -> {issuer, participants |> MapSet.delete(issuer) |> MapSet.size()} end)
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    merged_init_opts =
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.put(:state, {})

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  defp defaults do
    [
      flush_interval: :timer.seconds(3),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      task_supervisor: Indexer.Fetcher.TokenTransferPoisoning.TaskSupervisor,
      metadata: [fetcher: :token_transfer_poisoning]
    ]
  end

  # Nothing to stream on start: only transfers imported from now on are scored
  @impl BufferedTask
  def init(initial, _reducer, _) do
    initial
  end

  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Fetcher.TokenTransferPoisoning.run/2",
              service: :indexer,
              tracer: Tracer
            )
  def run(entries, _) do
    config = Config.load()

    attacks =
      entries
      |> Detector.detect()
      |> Enum.filter(&Result.storable?(&1, config))

    {count, _} = attacks |> Enum.map(&Result.to_attack_params/1) |> PoisoningAttack.insert_all()

    if count > 0 do
      Logger.info("Recorded #{count} token transfer poisoning attack(s)")
    end

    Actions.apply(attacks, config)

    :ok
  rescue
    reason ->
      Logger.error(fn ->
        ["failed to score token transfers for poisoning attacks: ", Exception.format(:error, reason, __STACKTRACE__)]
      end)

      {:retry, entries}
  end
end
