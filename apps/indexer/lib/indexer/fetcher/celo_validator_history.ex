defmodule Indexer.Fetcher.CeloValidatorHistory do
  @moduledoc """
  Fetches Celo validator history.
  """
  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Indexer.Fetcher.CeloValidatorHistory.Supervisor, as: CeloValidatorHistorySupervisor

  alias Explorer.Celo.AccountReader
  alias Explorer.Chain
  alias Explorer.Chain.{CeloParams, CeloValidatorHistory, CeloValidatorStatus}

  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Util

  use BufferedTask

  @max_retries 3

  def async_fetch(range) do
    if CeloValidatorHistorySupervisor.disabled?() do
      :ok
    else
      params = Enum.map(range, &entry/1)

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
    Util.default_child_spec(init_options, gen_server_options, __MODULE__)
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
        {:ok, data} -> data
        error -> Map.put(block, :error, error)
      end
    end)
  end

  defp get_status_items(block) do
    Enum.reduce(block.validators, {[], []}, fn
      %{error: _error} = item, {failed, success} ->
        {[item | failed], success}

      item, {failed, success} ->
        status = %{
          last_elected: block.block_number,
          signer_address_hash: item.address
        }

        online_status =
          if item.online do
            Map.put(status, :last_online, block.block_number)
          else
            item
          end

        changeset = CeloValidatorStatus.changeset(%CeloValidatorStatus{}, online_status)

        if changeset.valid? do
          {failed, [changeset.changes | success]}
        else
          {[item | failed], success}
        end
    end)
  end

  defp get_items(block) do
    Enum.reduce(block.validators, {[], []}, fn
      %{error: _error} = item, {failed, success} ->
        {[item | failed], success}

      item, {failed, success} ->
        changeset =
          CeloValidatorHistory.changeset(%CeloValidatorHistory{}, Map.put(item, :block_number, block.block_number))

        if changeset.valid? do
          {failed, [changeset.changes | success]}
        else
          {[item | failed], success}
        end
    end)
  end

  defp get_params(block) do
    Enum.reduce(block.params, {[], []}, fn
      %{error: _error} = item, {failed, success} ->
        {[item | failed], success}

      item, {failed, success} ->
        changeset = CeloParams.changeset(%CeloParams{}, Map.put(item, :block_number, block.block_number))

        if changeset.valid? do
          {failed, [changeset.changes | success]}
        else
          {[item | failed], success}
        end
    end)
  end

  defp import_items(blocks) do
    {failed, success_history} =
      Enum.reduce(blocks, {[], []}, fn
        %{error: _error} = block, {failed, success} ->
          {[block | failed], success}

        block, {failed, success} ->
          {_, success2} = get_items(block)
          {failed, success ++ success2}
      end)

    {_failed2, success_status} =
      Enum.reduce(blocks, {[], []}, fn
        %{error: _error} = block, {failed, success} ->
          {[block | failed], success}

        block, {failed, success} ->
          {_, success2} = get_status_items(block)
          {failed, success ++ success2}
      end)

    {_failed2, success_params} =
      Enum.reduce(blocks, {[], []}, fn
        %{error: _error} = block, {failed, success} ->
          {[block | failed], success}

        block, {failed, success} ->
          {_, success2} = get_params(block)
          {failed, success ++ success2}
      end)

    import_params = %{
      celo_params: %{params: success_params},
      celo_validator_history: %{params: success_history},
      celo_validator_status: %{params: success_status},
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
