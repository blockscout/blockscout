defmodule Indexer.Fetcher.CeloVoterVotes do
  @moduledoc """
  Fetches Celo voter votes.
  """
  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Explorer.Celo.{AccountReader, ContractEvents}
  alias Explorer.Chain
  alias Explorer.Chain.{Block, Hash}
  alias Explorer.Chain.CeloVoterVotes, as: CeloVoterVotesChain

  alias ContractEvents.Election.ValidatorGroupVoteActivatedEvent

  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Util

  @behaviour BufferedTask

  @spec async_fetch([%{block_hash: Hash.Full.t(), block_number: Block.block_number()}]) :: :ok
  def async_fetch(blocks) when is_list(blocks) do
    filtered_blocks =
      blocks
      |> Enum.filter(&(rem(&1.block_number, 17_280) == 0))

    BufferedTask.buffer(__MODULE__, filtered_blocks)
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    init_options_with_polling =
      init_options
      |> Keyword.put(:poll, true)
      |> Keyword.put(:poll_interval, :timer.minutes(60))
      |> Keyword.put(:max_batch_size, 10)

    Util.default_child_spec(init_options_with_polling, gen_server_options, __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _json_rpc_named_arguments) do
    {:ok, final} =
      Chain.stream_blocks_with_unfetched_voter_votes(initial, fn block, acc ->
        block
        |> reducer.(acc)
      end)

    final
  end

  @impl BufferedTask
  def run(entries, _json_rpc_named_arguments) do
    failed_list =
      entries
      |> Enum.map(&get_previous_epoch_voters_and_groups/1)
      |> List.flatten()
      |> Enum.uniq_by(&{&1.block_hash, &1.account_hash, &1.group_hash})
      |> Enum.map(&fetch_from_blockchain/1)
      |> import_items()

    if failed_list == [] do
      :ok
    else
      uniq_failed =
        failed_list
        |> Enum.uniq_by(&{&1.block_hash})

      {:retry, uniq_failed}
    end
  end

  def get_previous_epoch_voters_and_groups(%{block_hash: block_hash, block_number: block_number}) do
    account_group_pairs = ValidatorGroupVoteActivatedEvent.get_account_group_pairs_with_activated_votes(block_number)

    account_group_pairs
    |> Enum.map(&Map.merge(&1, %{block_hash: block_hash, block_number: block_number}))
  end

  def fetch_from_blockchain(entry) do
    case AccountReader.active_votes(entry) do
      {:ok, data} ->
        data

      error ->
        Logger.debug(inspect(error))
        Map.put(entry, :error, error)
    end
  end

  def import_items(votes) do
    {failed, success} =
      Enum.reduce(votes, {[], []}, fn
        %{error: _error} = vote, {failed, success} ->
          {[vote | failed], success}

        vote, {failed, success} ->
          changeset = CeloVoterVotesChain.changeset(%CeloVoterVotesChain{}, vote)

          if changeset.valid? do
            {failed, [changeset.changes | success]}
          else
            Logger.error(fn -> "changeset errors" end,
              errors: changeset.errors
            )

            {[vote | failed], success}
          end
      end)

    import_params = %{
      celo_voter_votes: %{params: success},
      timeout: :infinity
    }

    if failed != [] do
      Logger.error(fn -> "requeuing voter votes" end,
        block_numbers: Enum.map(failed, fn votes -> votes.block_number end)
      )
    end

    case Chain.import(import_params) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error(fn -> ["failed to import Celo voter votes data: ", inspect(reason)] end,
          error_count: Enum.count(votes)
        )
    end

    failed
  end
end
