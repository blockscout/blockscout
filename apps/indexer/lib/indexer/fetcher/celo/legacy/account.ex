defmodule Indexer.Fetcher.Celo.Legacy.Account do
  @moduledoc """
  Fetches Celo accounts.
  """

  alias Explorer.Chain
  alias Explorer.Chain.Celo.Account
  alias Indexer.Fetcher.Celo.Legacy.Account.Reader, as: AccountReader

  alias Indexer.BufferedTask
  alias Indexer.Transform.Celo.Legacy.Accounts, as: AccountsTransform

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
      poll: true,
      flush_interval: :timer.seconds(3),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      task_supervisor: __MODULE__.TaskSupervisor,
      metadata: [fetcher: :celo_accounts]
    ]
  end

  def async_fetch(logs, realtime?, timeout \\ 5000) when is_list(logs) do
    if __MODULE__.Supervisor.disabled?() do
      :ok
    else
      %{
        accounts: accounts,
        attestations_fulfilled: attestations_fulfilled,
        attestations_requested: attestations_requested
      } = AccountsTransform.parse(logs)

      dbg(logs)

      dbg(attestations_fulfilled)
      dbg(attestations_requested)

      dbg(accounts |> Enum.reject(&String.starts_with?(&1.address, "0x")))

      accounts = Enum.uniq(accounts ++ attestations_fulfilled ++ attestations_requested)
      dbg(accounts |> Enum.reject(&String.starts_with?(&1.address, "0x")))

      params =
        accounts
        |> Enum.map(fn a ->
          entry(
            a,
            attestations_fulfilled,
            attestations_requested
          )
        end)

      dbg(params |> Enum.reject(&String.starts_with?(&1.address, "0x")))

      BufferedTask.buffer(__MODULE__, params, realtime?, timeout)
    end
  end

  def entry(%{address: address}, requested, fulfilled) do
    %{
      address: address,
      attestations_fulfilled: Enum.count(fulfilled, &(&1.address == address)),
      attestations_requested: Enum.count(requested, &(&1.address == address))
    }
  end

  def entry(%{voter: address}, _, _) do
    %{
      voter: address,
      attestations_fulfilled: 0,
      attestations_requested: 0
    }
  end

  @impl BufferedTask
  def init(initial, _, _) do
    initial
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
      dbg(failed_list)
      {:retry, failed_list}
    end
  end

  defp fetch_from_blockchain(addresses) do
    addresses
    |> Enum.map(fn
      %{voter: _} = account ->
        Map.put(account, :error, :unresolved_voter)

      account ->
        case AccountReader.fetch(account.address) do
          {:ok, data} ->
            Map.merge(account, data)

          error ->
            Map.put(account, :error, error)
        end
    end)
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
      {:ok, accounts} ->
        Logger.info(fn -> ["Imported #{length(accounts)} Celo accounts."] end,
          error_count: Enum.count(failed)
        )

        failed

      {:error, reason} ->
        Logger.error(fn -> ["failed to import Celo account data: ", inspect(reason)] end,
          error_count: Enum.count(accounts)
        )

        accounts
    end
  end
end
