defmodule Indexer.Fetcher.TokenInstance.Realtime do
  @moduledoc """
  Fetches information about a token instance.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  import Indexer.Fetcher.TokenInstance.Helper

  alias Explorer.Chain
  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @default_max_batch_size 1
  @default_max_concurrency 10

  @doc false
  def child_spec([init_options, gen_server_options]) do
    merged_init_opts =
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.merge(state: [])

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(_, _, _) do
    {0, []}
  end

  @impl BufferedTask
  def run(token_instances, _) when is_list(token_instances) do
    token_instances
    |> Enum.filter(fn %{contract_address_hash: hash, token_id: token_id} ->
      not Chain.token_instance_exists?(token_id, hash)
    end)
    |> batch_fetch_instances()

    :ok
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
      |> Enum.reject(fn token_transfer -> is_nil(token_transfer.token_ids) end)
      |> Enum.map(fn token_transfer ->
        Enum.map(token_transfer.token_ids, fn token_id ->
          %{
            contract_address_hash: token_transfer.token_contract_address_hash,
            token_id: token_id
          }
        end)
      end)
      |> List.flatten()
      |> Enum.uniq()

    BufferedTask.buffer(__MODULE__, data)
  end

  def async_fetch(data, _disabled?) do
    BufferedTask.buffer(__MODULE__, data)
  end

  defp defaults do
    [
      flush_interval: 100,
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      poll: false,
      task_supervisor: __MODULE__.TaskSupervisor
    ]
  end
end
