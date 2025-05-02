defmodule Indexer.Fetcher.Celo.EpochBlockOperations do
  @moduledoc """
  Tracks epoch blocks awaiting processing by the epoch fetcher.
  """

  import Explorer.Chain.Celo.Helper,
    only: [
      premigration_block_number?: 1
    ]

  import Ecto.Query, only: [from: 2]

  alias Ecto.Multi
  alias Ecto.Changeset
  alias Explorer.Chain
  alias Explorer.Chain.Block
  alias Explorer.Chain.Import
  alias Explorer.Repo
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Transform.Addresses
  alias Explorer.Chain.Import.Stage

  alias Explorer.Chain.Celo.{
    Epoch,
    EpochReward,
    ElectionReward
  }

  alias Explorer.Chain.Import.Runner.Celo.{
    Epochs,
    ElectionRewards,
    EpochRewards
  }

  alias Indexer.Fetcher.Celo.EpochBlockOperations.{
    DelegatedPaymentsPriorL2Migration,
    Distributions,
    ValidatorAndGroupPaymentsPriorL2Migration,
    ValidatorAndGroupPaymentsPostL2Migration,
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
      task_supervisor: __MODULE__.TaskSupervisor,
      metadata: [fetcher: :celo_epoch_rewards]
    ]
  end

  @spec async_fetch(
          [%{block_number: Block.block_number(), block_hash: Hash.Full}],
          boolean(),
          integer()
        ) :: :ok
  def async_fetch(entries, realtime?, timeout \\ 5000) when is_list(entries) do
    if __MODULE__.Supervisor.disabled?() do
      :ok
    else
      filtered_entries =
        entries
        |> Enum.filter(&(&1.start_processing_block_hash && &1.end_processing_block_hash))

      BufferedTask.buffer(__MODULE__, filtered_entries, realtime?, timeout)
    end
  end

  @impl BufferedTask
  def init(initial, reducer, _json_rpc_named_arguments) do
    {:ok, final} =
      Epoch.stream_unfetched_epochs(
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
  def run(epochs, json_rpc_named_arguments) do
    Enum.each(
      epochs,
      fn epoch ->
        epoch
        |> Repo.preload([
          :start_processing_block,
          :end_processing_block
        ])
        |> fetch(json_rpc_named_arguments)
      end
    )

    :ok
  end

  defp fetch(epoch, json_rpc_named_arguments) do
    {:ok, voter_payments} =
      VoterPayments.fetch(
        epoch,
        json_rpc_named_arguments
      )

    {:ok, validator_and_group_payments} =
      if premigration_block_number?(epoch.start_processing_block.number) do
        ValidatorAndGroupPaymentsPriorL2Migration.fetch(epoch)
      else
        ValidatorAndGroupPaymentsPostL2Migration.fetch(epoch)
      end

    {:ok, delegated_payments_prior_l2_migration} =
      if premigration_block_number?(epoch.start_processing_block.number) do
        validator_and_group_payments
        |> Enum.filter(&(&1.type == :validator))
        |> Enum.map(& &1.account_address_hash)
        |> DelegatedPaymentsPriorL2Migration.fetch(
          epoch,
          json_rpc_named_arguments
        )
      else
        {:ok, []}
      end

    {:ok, distributions} = Distributions.fetch(epoch)

    election_rewards =
      [
        voter_payments,
        validator_and_group_payments,
        delegated_payments_prior_l2_migration
      ]
      |> Enum.concat()
      |> Enum.filter(&(&1.amount > 0))

    addresses_params =
      Addresses.extract_addresses(%{
        celo_election_rewards: election_rewards
      })

    {:ok, imported_addresses} = Chain.import(%{addresses: %{params: addresses_params}})

    {:ok, import_multi} =
      Import.all_single_multi(
        [
          Epochs,
          ElectionRewards,
          EpochRewards
        ],
        %{
          celo_epoch_rewards: %{params: [distributions]},
          celo_election_rewards: %{params: election_rewards},
          celo_epochs: %{params: [%{number: epoch.number, fetched?: true}]}
        }
      )

    Multi.new()
    |> Multi.run(:acquire_processing_blocks, fn repo, _changes ->
      # First verify start block consensus and lock it to prevent changes during our operation
      processing_block_hashes = [
        epoch.start_processing_block_hash,
        epoch.end_processing_block_hash
      ]

      premigration? = premigration_block_number?(epoch.start_processing_block.number)

      query =
        from(b in Block.consensus_blocks_query(),
          where: b.hash in ^processing_block_hashes,
          order_by: [asc: b.hash],
          lock: "FOR SHARE"
        )

      query
      |> repo.all()
      |> case do
        [_] = blocks when premigration? ->
          {:ok, blocks}

        [_, _] = blocks ->
          {:ok, blocks}

        [] ->
          {:error, :processing_blocks_not_consensus}
      end
    end)
    |> Multi.append(import_multi)
    |> Repo.transaction()
    |> case do
      {:ok, results} ->
        Logger.info("Successfully fetched and imported epoch rewards for epoch number: #{epoch.number}")
        {:ok, results}

      {:error, :acquire_processing_blocks, :processing_blocks_not_consensus, _changes} ->
        Logger.error(
          "Skipped importing epoch rewards for epoch #{epoch.number} since processing blocks are not consensus"
        )

        {:error, :processing_blocks_not_consensus}

      {:error, operation, reason, _changes} ->
        Logger.error("Failed importing epoch rewards for epoch #{epoch.number} on #{operation}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
