defmodule Indexer.Fetcher.CeloUnlocked do
  @moduledoc """
  Fetches pending Celo.
  """
  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Indexer.Fetcher.CeloUnlocked.Supervisor, as: CeloUnlockedSupervisor

  alias Explorer.Celo.AccountReader
  alias Explorer.Chain
  alias Explorer.Chain.CeloUnlocked

  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Util

  use BufferedTask

  @max_retries 3

  def async_fetch(accounts) do
    if CeloUnlockedSupervisor.disabled?() do
      :ok
    else
      params =
        accounts.params
        |> Enum.map(&entry/1)

      BufferedTask.buffer(__MODULE__, params, :infinity)
    end
  end

  def entry(address) do
    %{
      address: address,
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
    |> Enum.map(fn %{address: address} = account ->
      case AccountReader.withdrawal_data(address) do
        {:ok, data} ->
          Map.merge(account, data)

        error ->
          Map.put(account, :error, error)
      end
    end)
  end

  defp get_withdrawals(account) do
    Enum.reduce(account.pending, {[], []}, fn
      %{error: _error} = account, {failed, success} ->
        {[account | failed], success}

      item, {failed, success} ->
        changeset = CeloUnlocked.changeset(%CeloUnlocked{}, item)

        if changeset.valid? do
          {failed, [changeset.changes | success]}
        else
          {[account | failed], success}
        end
    end)
  end

  defp import_items(accounts) do
    {failed, success} =
      Enum.reduce(accounts, {[], []}, fn
        %{error: _error} = account, {failed, success} ->
          {[account | failed], success}

        account, {failed, success} ->
          {failed2, success2} = get_withdrawals(account)
          {failed ++ failed2, success ++ success2}
      end)

    import_params = %{
      celo_unlocked: %{params: success},
      timeout: :infinity
    }

    case Chain.import(import_params) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.debug(fn -> ["failed to import pending Celo data: ", inspect(reason)] end,
          error_count: Enum.count(accounts)
        )
    end

    failed
  end
end
