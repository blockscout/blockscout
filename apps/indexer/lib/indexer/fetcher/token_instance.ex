defmodule Indexer.Fetcher.TokenInstance do
  @moduledoc """
  Fetches information about a token instance.
  """

  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Explorer.Celo.Telemetry
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Cache.BlockNumber, Token}
  alias Explorer.Token.{InstanceMetadataRetriever, InstanceOwnerReader}
  alias Indexer.BufferedTask

  use BufferedTask

  @defaults [
    flush_interval: 300,
    max_batch_size: 1,
    max_concurrency: 10,
    task_supervisor: Indexer.Fetcher.TokenInstance.TaskSupervisor
  ]

  @doc false
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_opts =
      @defaults
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial_acc, reducer, _) do
    {:ok, acc} =
      Chain.stream_unfetched_token_instances(initial_acc, fn data, acc ->
        reducer.(data, acc)
      end)

    acc
  end

  @impl BufferedTask
  def run([%{contract_address_hash: hash, token_id: token_id, token_ids: token_ids}], _json_rpc_named_arguments) do
    all_token_ids =
      cond do
        is_nil(token_id) -> token_ids
        is_nil(token_ids) -> [token_id]
        true -> [token_id] ++ token_ids
      end

    Enum.each(all_token_ids, &fetch_instance(hash, &1))
    update_current_token_balances(hash, all_token_ids)

    :ok
  end

  defp fetch_instance(token_contract_address_hash, token_id) do
    case InstanceMetadataRetriever.fetch_metadata(to_string(token_contract_address_hash), Decimal.to_integer(token_id)) do
      {:ok, %{metadata: metadata}} ->
        params = %{
          token_id: token_id,
          token_contract_address_hash: token_contract_address_hash,
          metadata: metadata,
          error: nil
        }

        {:ok, _result} = Chain.upsert_token_instance(params)

        Telemetry.event([:indexer, :nft, :ingested], %{count: 1})

      {:ok, %{error: error}} ->
        params = %{
          token_id: token_id,
          token_contract_address_hash: token_contract_address_hash,
          error: error
        }

        {:ok, _result} = Chain.upsert_token_instance(params)

        Telemetry.event([:indexer, :nft, :ingestion_error], %{count: 1})

      result ->
        Telemetry.event([:indexer, :nft, :ingestion_error], %{count: 1})

        Logger.debug(
          [
            "failed to fetch token instance metadata for #{inspect({to_string(token_contract_address_hash), Decimal.to_integer(token_id)})}: ",
            inspect(result)
          ],
          fetcher: :token_instances
        )

        :ok
    end
  end

  defp update_current_token_balances(token_contract_address_hash, token_ids) do
    token_ids
    |> Enum.map(&instance_owner_request(token_contract_address_hash, &1))
    |> InstanceOwnerReader.get_owner_of()
    |> Enum.map(&current_token_balances_import_params/1)
    |> all_import_params()
    |> Chain.import()
  end

  defp instance_owner_request(token_contract_address_hash, token_id) do
    %{
      token_contract_address_hash: to_string(token_contract_address_hash),
      token_id: Decimal.to_integer(token_id)
    }
  end

  defp current_token_balances_import_params(%{token_contract_address_hash: hash, token_id: token_id, owner: owner}) do
    %{
      value: Decimal.new(1),
      block_number: BlockNumber.get_max(),
      value_fetched_at: DateTime.utc_now(),
      token_id: token_id,
      token_type: Repo.get_by(Token, contract_address_hash: hash).type,
      address_hash: owner,
      token_contract_address_hash: hash
    }
  end

  defp all_import_params(balances_import_params) do
    addresses_import_params =
      balances_import_params
      |> Enum.reduce([], fn %{address_hash: address_hash}, acc ->
        case Repo.get_by(Address, hash: address_hash) do
          nil -> [%{hash: address_hash} | acc]
          _address -> acc
        end
      end)
      |> case do
        [] -> %{}
        params -> %{addresses: %{params: params}}
      end

    current_token_balances_import_params = %{
      address_current_token_balances: %{
        params: balances_import_params
      }
    }

    Map.merge(current_token_balances_import_params, addresses_import_params)
  end

  @doc """
  Fetches token instance data asynchronously.
  """
  def async_fetch(data) do
    async_fetch(data, __MODULE__.Supervisor.disabled?())
  end

  def async_fetch(_data, true), do: :ok

  def async_fetch(token_transfers, _disabled?) when is_list(token_transfers) do
    data =
      token_transfers
      |> Enum.reject(fn token_transfer -> is_nil(token_transfer.token_id) and is_nil(token_transfer.token_ids) end)
      |> Enum.map(fn token_transfer ->
        %{
          contract_address_hash: token_transfer.token_contract_address_hash,
          token_id: token_transfer.token_id,
          token_ids: token_transfer.token_ids
        }
      end)
      |> Enum.uniq()

    BufferedTask.buffer(__MODULE__, data)
  end

  def async_fetch(data, _disabled?) do
    BufferedTask.buffer(__MODULE__, data)
  end
end
