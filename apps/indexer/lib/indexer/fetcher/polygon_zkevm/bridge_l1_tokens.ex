defmodule Indexer.Fetcher.PolygonZkevm.BridgeL1Tokens do
  @moduledoc """
  Fetches information about L1 tokens for zkEVM bridge.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  import Ecto.Query

  alias Explorer.Repo
  alias Indexer.{BufferedTask, Helper}
  alias Indexer.Fetcher.PolygonZkevm.{Bridge, BridgeL1}

  @behaviour BufferedTask

  @default_max_batch_size 1
  @default_max_concurrency 10

  @doc false
  def child_spec([init_options, gen_server_options]) do
    rpc = Application.get_all_env(:indexer)[BridgeL1][:rpc]
    json_rpc_named_arguments = Helper.json_rpc_named_arguments(rpc)

    merged_init_opts =
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.merge(state: json_rpc_named_arguments)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(_, _, _) do
    {0, []}
  end

  @impl BufferedTask
  def run(l1_token_addresses, json_rpc_named_arguments) when is_list(l1_token_addresses) do
    l1_token_addresses
    |> Bridge.token_addresses_to_ids(json_rpc_named_arguments)
    |> Enum.each(fn {l1_token_address, l1_token_id} ->
      Repo.update_all(
        from(b in Explorer.Chain.PolygonZkevm.Bridge, where: b.l1_token_address == ^l1_token_address),
        set: [l1_token_id: l1_token_id, l1_token_address: nil]
      )
    end)
  end

  @doc """
  Fetches L1 token data asynchronously.
  """
  def async_fetch(data) do
    async_fetch(data, Application.get_env(:indexer, __MODULE__.Supervisor)[:enabled])
  end

  def async_fetch(_data, false), do: :ok

  def async_fetch(operations, _enabled) do
    l1_token_addresses =
      operations
      |> Enum.reject(fn operation -> is_nil(operation.l1_token_address) end)
      |> Enum.map(fn operation -> operation.l1_token_address end)
      |> Enum.uniq()

    BufferedTask.buffer(__MODULE__, l1_token_addresses, true)
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
