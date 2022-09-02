defmodule Indexer.Fetcher.CeloAccount do
  @moduledoc """
  Fetches Celo accounts.
  """
  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Indexer.Fetcher.CeloAccount.Supervisor, as: CeloAccountSupervisor

  alias Explorer.Celo.AccountReader
  alias Explorer.Chain
  alias Explorer.Chain.CeloAccount

  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Util

  use BufferedTask

  @max_retries 3

  def async_fetch(accounts) do
    if CeloAccountSupervisor.disabled?() do
      :ok
    else
      params =
        accounts.params
        |> Enum.map(fn a -> entry(a, accounts.requested, accounts.fulfilled) end)

      BufferedTask.buffer(__MODULE__, params, :infinity)
    end
  end

  def entry(%{address: address}, requested, fulfilled) do
    %{
      address: address,
      attestations_fulfilled: Enum.count(Enum.filter(fulfilled, fn a -> a.address == address end)),
      attestations_requested: Enum.count(Enum.filter(requested, fn a -> a.address == address end)),
      retries_count: 0
    }
  end

  def entry(%{voter: address}, _, _) do
    %{
      voter: address,
      attestations_fulfilled: 0,
      attestations_requested: 0,
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
      |> Enum.filter(&(&1.retries_count <= @max_retries))
      |> fetch_from_blockchain()
      |> import_accounts()

    if failed_list == [] do
      :ok
    else
      {:retry, failed_list}
    end
  end

  defp fetch_from_blockchain(addresses) do
    addresses
    |> Enum.map(fn
      %{voter: _} = account ->
        Map.put(account, :error, :unresolved_voter)

      account ->
        case AccountReader.account_data(account) do
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
          changeset = CeloAccount.changeset(%CeloAccount{}, account)

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
      {:ok, _} ->
        failed

      {:error, reason} ->
        Logger.debug(fn -> ["failed to import Celo account data: ", inspect(reason)] end,
          error_count: Enum.count(accounts)
        )

        accounts
    end
  end
end
