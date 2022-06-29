defmodule Indexer.Fetcher.CeloEpochRewards do
  @moduledoc """
  Fetches Celo voter rewards for groups.
  """
  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Explorer.Celo.{AccountReader, EpochUtil}
  alias Explorer.Chain
  alias Explorer.Chain.{Block, CeloEpochRewards, Hash}

  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Util

  @behaviour BufferedTask

  @spec async_fetch([%{block_hash: Hash.Full.t(), block_number: Block.block_number()}]) :: :ok
  def async_fetch(blocks) when is_list(blocks) do
    filtered_blocks =
      blocks
      |> Enum.filter(fn block -> EpochUtil.is_epoch_block?(block.block_number) end)

    BufferedTask.buffer(__MODULE__, filtered_blocks)
  end

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
      case AccountReader.epoch_reward_data(block) do
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
