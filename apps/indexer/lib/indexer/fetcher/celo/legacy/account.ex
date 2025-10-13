defmodule Indexer.Fetcher.Celo.Legacy.Account do
  @moduledoc """
  Asynchronously fetches Celo blockchain account data from event logs and
  imports them into the database.

  This fetcher processes blockchain logs to extract account-related events,
  retrieves detailed account information from Celo smart contracts, and performs
  bulk imports of account data. It supports batching and concurrency for
  efficient processing.

  The fetcher integrates with the BufferedTask system to handle asynchronous
  processing and automatic retry logic for failed operations.

  ## Note

  This implementation is ported from Celo's fork of Blockscout and could be
  revised in future iterations.
  """

  alias Explorer.Chain
  alias Explorer.Chain.Celo.PendingAccountOperation
  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Celo.Legacy.Account.Reader, as: AccountReader
  alias Indexer.Transform.Addresses

  require Logger

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  @behaviour BufferedTask

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
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency],
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size],
      task_supervisor: __MODULE__.TaskSupervisor,
      metadata: [fetcher: :celo_accounts]
    ]
  end

  @doc """
  Asynchronously enqueues processing of Celo account operations.

  ## Parameters
  - `operations`: List of `PendingAccountOperation` structs to process
  - `realtime?`: Boolean indicating if this is realtime processing
  - `timeout`: Timeout for buffering tasks (default: 5000ms)

  ## Returns
  - `:ok` once the operations have been enqueued
  """
  @spec async_fetch([PendingAccountOperation.t()], boolean(), timeout()) :: :ok
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
    accounts
    |> fetch_from_blockchain()
    |> import_accounts()
    |> case do
      :ok -> :ok
      :error -> {:retry, accounts}
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
    addresses =
      Addresses.extract_addresses(%{
        celo_accounts: accounts
      })

    import_params = %{
      addresses: %{
        params: addresses,
        timeout: :infinity
      },
      celo_accounts: %{
        params: accounts,
        timeout: :infinity
      }
    }

    case Chain.import(import_params) do
      {:ok, _imported} ->
        Logger.info("Imported #{Enum.count(accounts)} Celo accounts.")

        accounts
        |> Enum.map(& &1.address_hash)
        |> PendingAccountOperation.delete_by_address_hashes()

        :ok

      {:error, reason} ->
        Logger.error(fn -> ["failed to import Celo account data: ", inspect(reason)] end)

        :error
    end
  end
end
