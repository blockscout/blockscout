defmodule Indexer.Fetcher.Celo.EpochBlockOperations do
  @moduledoc """
  Tracks epoch blocks awaiting processing by the epoch fetcher.
  """

  import Explorer.Chain.Celo.Helper,
    only: [
      epoch_block_number?: 1,
      premigration_block_number?: 1
    ]

  alias Explorer.Chain
  alias Explorer.Chain.Block
  alias Explorer.Chain.Celo.PendingEpochBlockOperation
  alias Indexer.Fetcher.Celo.EpochBlockOperations.Supervisor, as: EpochBlockOperationsSupervisor
  alias Indexer.Transform.Addresses
  alias Indexer.{BufferedTask, Tracer}

  alias Indexer.Fetcher.Celo.EpochBlockOperations.{
    DelegatedPayments,
    Distributions,
    ValidatorAndGroupPayments,
    VoterPayments
  }

  require Logger

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  @behaviour BufferedTask

  @default_max_batch_size 1
  @default_max_concurrency 1

  @doc false
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec` " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_opts =
      defaults()
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  def defaults do
    [
      poll: false,
      flush_interval: :timer.seconds(3),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      task_supervisor: Indexer.Fetcher.Celo.EpochBlockOperations.TaskSupervisor,
      metadata: [fetcher: :celo_epoch_rewards]
    ]
  end

  @spec async_fetch(
          [%{block_number: Block.block_number(), block_hash: Hash.Full}],
          boolean(),
          integer()
        ) :: :ok
  def async_fetch(entries, realtime?, timeout \\ 5000) when is_list(entries) do
    if EpochBlockOperationsSupervisor.disabled?() do
      :ok
    else
      filtered_entries =
        Enum.filter(
          entries,
          &(epoch_block_number?(&1.block_number) &&
              premigration_block_number?(&1.block_number))
        )

      BufferedTask.buffer(__MODULE__, filtered_entries, realtime?, timeout)
    end
  end

  @impl BufferedTask
  def init(initial, reducer, _json_rpc_named_arguments) do
    {:ok, final} =
      PendingEpochBlockOperation.stream_premigration_epoch_blocks_with_unfetched_rewards(
        initial,
        reducer,
        true
      )

    final
  end

  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Fetcher.Celo.EpochBlockOperations.run/2",
              service: :indexer,
              tracer: Tracer
            )
  def run(pending_operations, json_rpc_named_arguments) do
    Enum.each(pending_operations, fn pending_operation ->
      fetch(pending_operation, json_rpc_named_arguments)
    end)

    :ok
  end

  defp fetch(pending_operation, json_rpc_named_arguments) do
    {:ok, distributions} = Distributions.fetch(pending_operation)
    {:ok, validator_and_group_payments} = ValidatorAndGroupPayments.fetch(pending_operation)

    {:ok, voter_payments} =
      VoterPayments.fetch(
        pending_operation,
        json_rpc_named_arguments
      )

    {:ok, delegated_payments} =
      validator_and_group_payments
      |> Enum.filter(&(&1.type == :validator))
      |> Enum.map(& &1.account_address_hash)
      |> DelegatedPayments.fetch(
        pending_operation,
        json_rpc_named_arguments
      )

    election_rewards =
      [
        validator_and_group_payments,
        voter_payments,
        delegated_payments
      ]
      |> Enum.concat()
      |> Enum.filter(&(&1.amount > 0))

    addresses_params =
      Addresses.extract_addresses(%{
        celo_election_rewards: election_rewards
      })

    {:ok, imported} =
      Chain.import(%{
        addresses: %{params: addresses_params},
        celo_election_rewards: %{params: election_rewards},
        celo_epoch_rewards: %{params: [distributions]}
      })

    Logger.info("Fetched epoch rewards for block number: #{pending_operation.block_number}")

    {:ok, imported}
  end
end
