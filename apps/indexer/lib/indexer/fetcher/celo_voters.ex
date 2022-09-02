defmodule Indexer.Fetcher.CeloVoters do
  @moduledoc """
  Fetches Celo validator group voters.
  """
  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Indexer.Fetcher.CeloVoters.Supervisor, as: CeloVotersSupervisor

  alias Explorer.Celo.AccountReader
  alias Explorer.Chain
  alias Explorer.Chain.CeloVoters

  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Util

  use BufferedTask

  @max_retries 3

  def async_fetch(accounts) do
    if CeloVotersSupervisor.disabled?() do
      :ok
    else
      params =
        accounts.params
        |> Enum.map(&entry/1)

      BufferedTask.buffer(__MODULE__, params, :infinity)
    end
  end

  @spec entry(%{group_address: String.t(), voter_address: String.t()}) :: %{
          group_address_hash: String.t(),
          voter_address_hash: String.t(),
          retries_count: integer
        }
  def entry(%{group_address: group_address, voter_address: voter_address}) do
    %{
      group_address_hash: group_address,
      voter_address_hash: voter_address,
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
    |> Enum.map(fn %{group_address_hash: group_address, voter_address_hash: voter_address} = account ->
      case AccountReader.voter_data(group_address, voter_address) do
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
          changeset = CeloVoters.changeset(%CeloVoters{}, account)

          if changeset.valid? do
            {failed, [changeset.changes | success]}
          else
            {[account | failed], success}
          end
      end)

    import_params = %{
      celo_voters: %{params: success},
      timeout: :infinity
    }

    case Chain.import(import_params) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.debug(fn -> ["failed to import Celo voter data: ", inspect(reason)] end,
          error_count: Enum.count(accounts)
        )
    end

    failed
  end
end
