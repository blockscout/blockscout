defmodule Indexer.Fetcher.CeloVoterRewards do
  @moduledoc """
  Fetches Celo voter rewards for groups.
  """
  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Indexer.Fetcher.CeloVoterRewards.Supervisor, as: CeloVoterRewardsSupervisor

  alias Explorer.Celo.AccountReader
  alias Explorer.Chain
  alias Explorer.Chain.CeloVoterRewards

  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Util

  @behaviour BufferedTask

  @max_retries 3

  def async_fetch(accounts) do
    if CeloVoterRewardsSupervisor.disabled?() do
      :ok
    else
      params =
        accounts.params
        |> Enum.map(&entry/1)

      BufferedTask.buffer(__MODULE__, params, :infinity)
    end
  end

  def entry(elem) do
    %{
      address_hash: elem.address_hash,
      block_hash: elem.block_hash,
      log_index: elem.log_index,
      reward: elem.reward,
      block_number: elem.block_number,
      retries_count: 0
    }
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    Util.default_child_spec(init_options, gen_server_options, __MODULE__)
  end

  @impl BufferedTask
  def init(initial, _, _) do
    initial
  end

  @impl BufferedTask
  def run(accounts, _json_rpc_named_arguments) do
    failed_list =
      accounts
      |> Enum.map(&Map.put(&1, :retries_count, &1.retries_count + 1))
      |> fetch_from_blockchain()
      |> import_items()

    if failed_list == [] do
      :ok
    else
      {:retry, failed_list}
    end
  end

  defp fetch_from_blockchain(addresses) do
    addresses
    |> Enum.filter(&(&1.retries_count <= @max_retries))
    |> Enum.map(fn %{address_hash: address} = account ->
      case AccountReader.validator_group_reward_data(address) do
        {:ok, data} ->
          Map.merge(account, data)

        error ->
          Map.put(account, :error, error)
      end
    end)
  end

  defp import_items(accounts) do
    {failed, success} =
      Enum.reduce(accounts, {[], []}, fn
        %{error: _error} = account, {failed, success} ->
          {[account | failed], success}

        account, {failed, success} ->
          changeset = CeloVoterRewards.changeset(%CeloVoterRewards{}, account)

          if changeset.valid? do
            {failed, [changeset.changes | success]}
          else
            {[account | failed], success}
          end
      end)

    import_params = %{
      celo_voter_rewards: %{params: success},
      timeout: :infinity
    }

    case Chain.import(import_params) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.debug(fn -> ["failed to import Celo voter reward data: ", inspect(reason)] end,
          error_count: Enum.count(accounts)
        )
    end

    failed
  end
end
