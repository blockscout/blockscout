defmodule Indexer.Fetcher.CeloValidatorHistory do
  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Indexer.Fetcher.CeloValidatorHistory.Supervisor, as: CeloValidatorHistorySupervisor
  alias Explorer.Chain.CeloValidatorHistory
  alias Explorer.Chain
  alias Explorer.Celo.AccountReader

  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @max_retries 3

  def async_fetch(blocks) do
    if CeloValidatorHistorySupervisor.disabled?() do
      :ok
    else
      params =
        blocks.params
        |> Enum.map(&entry/1)

      BufferedTask.buffer(__MODULE__, params, :infinity)
    end
  end

  def entry(block_number) do
    %{
      block_number: block_number,
      retries_count: 0
    }
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    Indexer.Fetcher.Util.default_child_spec(init_options, gen_server_options, __MODULE__)
  end

  @impl BufferedTask
  def init(initial, _, _) do
    initial
  end

  @impl BufferedTask
  def run(blocks, _json_rpc_named_arguments) do
    failed_list =
      blocks
      |> Enum.map(&Map.put(&1, :retries_count, &1.retries_count + 1))
      |> fetch_from_blockchain()
      |> import_items()

    if failed_list == [] do
      :ok
    else
      {:retry, failed_list}
    end
  end

  defp fetch_from_blockchain(blocks) do
    blocks
    |> Enum.filter(&(&1.retries_count <= @max_retries))
    |> Enum.map(fn %{block_number: block_number} = block ->
      case AccountReader.validator_history(block_number) do
        {:ok, data} ->
          Map.merge(block, data)

        error ->
          Map.put(block, :error, error)
      end
    end)
  end

  defp import_items(blocks) do
    {failed, success} =
      Enum.reduce(blocks, {[], []}, fn
        %{error: _error} = block, {failed, success} ->
          {[block | failed], success}

        block, {failed, success} ->
          changeset = CeloValidatorHistory.changeset(%CeloValidatorHistory{}, block)

          if changeset.valid? do
            {failed, [changeset.changes | success]}
          else
            {[block | failed], success}
          end
      end)

    import_params = %{
      celo_validator_history: %{params: success},
      timeout: :infinity
    }

    case Chain.import(import_params) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.debug(fn -> ["failed to import Celo validator history data: ", inspect(reason)] end,
          error_count: Enum.count(blocks)
        )
    end

    failed
  end
end
