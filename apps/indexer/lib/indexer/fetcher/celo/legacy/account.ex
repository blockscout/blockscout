defmodule Indexer.Fetcher.Celo.Legacy.Account do
  @moduledoc """
  Fetches Celo accounts.

  TODO: this implementation is ported from the celo's fork of blockscout and
  could be improved in the future.
  """

  alias Explorer.Chain
  alias Explorer.Chain.Celo.{Account, PendingAccountOperation}
  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Celo.Legacy.Account.Reader, as: AccountReader

  require Logger

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  @behaviour BufferedTask

  @default_max_batch_size 10
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
      poll: true,
      flush_interval: :timer.seconds(3),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      task_supervisor: __MODULE__.TaskSupervisor,
      metadata: [fetcher: :celo_accounts]
    ]
  end

  @spec async_fetch([PendingAccountOperation.t()], boolean(), timeout()) ::
          :ok | {:retry, [map()]} | :disabled
  def async_fetch(operations, realtime?, timeout \\ 5000) when is_list(operations) do
    if __MODULE__.Supervisor.disabled?() do
      :ok
    else
      unique_operations = Enum.uniq_by(operations, & &1.address_hash)
      BufferedTask.buffer(__MODULE__, unique_operations, realtime?, timeout)
    end
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    {:ok, final} =
      PendingAccountOperation.stream(
        initial,
        reducer,
        true
      )

    final
  end

  @impl BufferedTask
  def run(accounts, _json_rpc_named_arguments) do
    failed_list =
      accounts
      |> fetch_from_blockchain()
      |> import_accounts()

    if failed_list == [] do
      :ok
    else
      {:retry, failed_list}
    end
  end

  defp fetch_from_blockchain(operations) do
    operations
    |> Enum.map(fn
      %{voter: _} = account ->
        Map.put(account, :error, :unresolved_voter)

      account ->
        account.address_hash
        |> to_string()
        |> AccountReader.fetch()
        |> case do
          {:ok, data} -> data
          _ -> nil
        end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp import_accounts(accounts) do
    {failed, success} =
      Enum.reduce(accounts, {[], []}, fn
        %{error: _error} = account, {failed, success} ->
          {[account | failed], success}

        account, {failed, success} ->
          changeset = Account.changeset(%Account{}, account)

          if changeset.valid? do
            {failed, [changeset.changes | success]}
          else
            {[account | failed], success}
          end
      end)

    import_params = %{
      celo_accounts: %{params: success},
      timeout: :infinity
    }

    case Chain.import(import_params) do
      {:ok, _imported} ->
        Logger.info(fn -> ["Imported #{Enum.count(success)} Celo accounts."] end,
          error_count: Enum.count(failed)
        )

        success
        |> Enum.map(& &1.address_hash)
        |> PendingAccountOperation.delete_by_address_hashes()

        failed

      {:error, reason} ->
        Logger.error(fn -> ["failed to import Celo account data: ", inspect(reason)] end,
          error_count: Enum.count(accounts)
        )

        accounts
    end
  end
end
