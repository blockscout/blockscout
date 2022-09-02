defmodule Indexer.Fetcher.CeloValidator do
  @moduledoc """
  Fetches Celo validators.
  """
  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Indexer.Fetcher.CeloValidator.Supervisor, as: CeloValidatorSupervisor

  alias Explorer.Celo.AccountReader
  alias Explorer.Chain
  alias Explorer.Chain.CeloValidator

  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Util

  use BufferedTask

  @max_retries 3

  def async_fetch(accounts) do
    if CeloValidatorSupervisor.disabled?() do
      :ok
    else
      params =
        accounts.params
        |> Enum.map(&entry/1)

      BufferedTask.buffer(__MODULE__, params, :infinity)
    end
  end

  @spec entry(%{address: String.t()}) :: %{address: String.t(), retries_count: integer}
  def entry(%{address: address}) do
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

  defp group_to_member_aux(entry) do
    case AccountReader.validator_group_members(entry.address) do
      {:ok, res} ->
        Enum.map(res, fn a -> entry(%{address: "0x" <> Base.encode16(a, lower: true)}) end)

      _ ->
        []
    end
  end

  defp group_to_member(entry) do
    case AccountReader.is_validator_group(entry.address) do
      {:ok, true} ->
        group_to_member_aux(entry)

      _ ->
        [entry]
    end
  end

  defp groups_to_members(entries) do
    Enum.reduce(entries, [], fn entry, acc ->
      group_to_member(entry) ++ acc
    end)
  end

  defp fetch_from_blockchain(addresses) do
    addresses
    |> Enum.filter(&(&1.retries_count <= @max_retries))
    |> groups_to_members()
    |> Enum.map(fn %{address: address} = account ->
      case AccountReader.validator_data(address) do
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
          changeset = CeloValidator.changeset(%CeloValidator{}, account)

          if changeset.valid? do
            {failed, [changeset.changes | success]}
          else
            {[account | failed], success}
          end
      end)

    import_params = %{
      celo_validators: %{params: success},
      timeout: :infinity
    }

    case Chain.import(import_params) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.debug(fn -> ["failed to import Celo validator data: ", inspect(reason)] end,
          error_count: Enum.count(accounts)
        )
    end

    failed
  end
end
