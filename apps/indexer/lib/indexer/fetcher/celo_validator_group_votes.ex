defmodule Indexer.Fetcher.CeloValidatorGroupVotes do
  @moduledoc """
  Fetches Celo voter rewards for groups.
  """
  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Explorer.Celo.{AccountReader, ContractEvents}
  alias Explorer.Chain
  alias Explorer.Chain.{CeloValidatorGroupVotes, Hash}

  alias ContractEvents.Election.EpochRewardsDistributedToVotersEvent

  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Util

  @behaviour BufferedTask

  @doc false
  def child_spec([init_options, gen_server_options]) do
    init_options_with_polling =
      init_options
      |> Keyword.put(:poll, true)
      |> Keyword.put(:poll_interval, :timer.minutes(60))

    Util.default_child_spec(init_options_with_polling, gen_server_options, __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _json_rpc_named_arguments) do
    {:ok, final} =
      Chain.stream_blocks_with_unfetched_validator_group_data(initial, fn block, acc ->
        block
        |> reducer.(acc)
      end)

    final
  end

  @impl BufferedTask
  def run(entries, _json_rpc_named_arguments) do
    failed_list =
      entries
      |> fetch_from_blockchain()
      |> import_items()

    if failed_list == [] do
      :ok
    else
      {:retry, failed_list}
    end
  end

  def fetch_from_blockchain(blocks) do
    blocks
    |> Enum.flat_map(fn block ->
      elected_groups = EpochRewardsDistributedToVotersEvent.elected_groups_for_block(block.block_number)

      Enum.map(elected_groups, fn group_hash_string ->
        do_fetch_from_blockchain(block, group_hash_string)
      end)
    end)
  end

  def do_fetch_from_blockchain(block, group_hash_string) do
    {:ok, group_hash} = Hash.Address.cast(group_hash_string)

    case AccountReader.validator_group_votes(block, group_hash) do
      {:ok, data} ->
        data

      error ->
        Logger.debug(inspect(error))
        Map.put(block, :error, error)
    end
  end

  def import_items(rewards) do
    {failed, success} =
      Enum.reduce(rewards, {[], []}, fn
        %{error: _error} = reward, {failed, success} ->
          {[reward | failed], success}

        reward, {failed, success} ->
          changeset = CeloValidatorGroupVotes.changeset(%CeloValidatorGroupVotes{}, reward)

          if changeset.valid? do
            {failed, [changeset.changes | success]}
          else
            Logger.error(fn -> "changeset errors" end,
              errors: changeset.errors
            )

            {[reward | failed], success}
          end
      end)

    import_params = %{
      celo_validator_group_votes: %{params: success},
      timeout: :infinity
    }

    if failed != [] do
      Logger.error(fn -> "requeuing group votes" end,
        block_numbers: Enum.map(failed, fn votes -> votes.block_number end)
      )
    end

    case Chain.import(import_params) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error(fn -> ["failed to import Celo epoch reward data: ", inspect(reason)] end,
          error_count: Enum.count(rewards)
        )
    end

    failed
  end
end
