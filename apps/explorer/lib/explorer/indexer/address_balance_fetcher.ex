defmodule Explorer.Indexer.AddressBalanceFetcher do
  @moduledoc """
  Fetches `t:Explorer.Chain.Address.t/0` `fetched_balance`.
  """

  alias Explorer.{BufferedTask, Chain}
  alias Explorer.Chain.{Hash, Address}
  alias Explorer.Indexer

  @behaviour BufferedTask

  @defaults [
    flush_interval: :timer.seconds(3),
    max_batch_size: 500,
    max_concurrency: 4,
    init_chunk_size: 1000,
    task_supervisor: Explorer.Indexer.TaskSupervisor
  ]

  @doc """
  Asynchronously fetches balances from list of `t:Explorer.Chain.Hash.t/0`.
  """
  def async_fetch_balances(address_hashes) do
    string_hashes = for hash <- address_hashes, do: Hash.to_string(hash)
    BufferedTask.buffer(__MODULE__, string_hashes)
  end

  @doc false
  def child_spec(provided_opts) do
    opts = Keyword.merge(@defaults, provided_opts)
    Supervisor.child_spec({BufferedTask, {__MODULE__, opts}}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(acc, reducer) do
    Chain.stream_unfetched_addresses([:hash], acc, fn %Address{hash: hash}, acc ->
      reducer.(Hash.to_string(hash), acc)
    end)
  end

  @impl BufferedTask
  def run(string_hashes, _retries) do
    Indexer.debug(fn -> "fetching #{length(string_hashes)} balances" end)

    case EthereumJSONRPC.fetch_balances_by_hash(string_hashes) do
      {:ok, results} ->
        :ok = Chain.update_balances(results)

      {:error, reason} ->
        Indexer.debug(fn -> "failed to fetch #{length(string_hashes)} balances, #{inspect(reason)}" end)
        {:retry, reason}
    end
  end
end
