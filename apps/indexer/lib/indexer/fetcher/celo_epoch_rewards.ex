defmodule Indexer.Fetcher.CeloEpochRewards do
  @moduledoc """
  Fetches Celo voter rewards for groups.
  """
  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Explorer.Celo.AccountReader
  alias Explorer.Chain
  alias Explorer.Chain.CeloEpochRewards

  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Util

  @behaviour BufferedTask

  @doc false
  def child_spec([init_options, gen_server_options]) do
    Util.default_child_spec(init_options, gen_server_options, __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _json_rpc_named_arguments) do
    {:ok, final} =
      Chain.stream_blocks_with_unfetched_epoch_rewards(initial, fn block, acc ->
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
    |> Enum.map(fn block ->
      case AccountReader.validator_group_reward_data(block) do
        {:ok, data} ->
          data

        error ->
          Logger.debug(inspect(error))
          Map.put(block, :error, error)
      end
    end)
  end

  def import_items(rewards) do
    {failed, success} =
      Enum.reduce(rewards, {[], []}, fn
        %{error: _error} = reward, {failed, success} ->
          {[reward | failed], success}

        reward, {failed, success} ->
          changeset = CeloEpochRewards.changeset(%CeloEpochRewards{}, reward)

          if changeset.valid? do
            {failed, [changeset.changes | success]}
          else
            {[reward | failed], success}
          end
      end)

    import_params = %{
      celo_epoch_rewards: %{params: success},
      timeout: :infinity
    }

    if failed != [] do
      Logger.error(fn -> "requeuing rewards" end,
        block_numbers: Enum.map(failed, fn rew -> rew.block_number end)
      )
    end

    case Chain.import_epoch_rewards_and_delete_pending_celo_epoch_operations(import_params, success) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error(fn -> ["failed to import Celo voter reward data: ", inspect(reason)] end,
          error_count: Enum.count(rewards)
        )
    end

    failed
  end
end
