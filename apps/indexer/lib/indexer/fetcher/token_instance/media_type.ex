# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.TokenInstance.MediaType do
  @moduledoc """
  Backfills MIME types for token instances that have metadata
  but missing image_type or animation_type.
  """

  require Logger

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  import Ecto.Query

  alias Explorer.Chain.Token.Instance
  alias Explorer.{QueryHelper, Repo}
  alias Indexer.BufferedTask
  alias Indexer.Fetcher.TokenInstance.Helper

  @behaviour BufferedTask

  @doc false
  def child_spec([init_options, gen_server_options]) do
    merged_init_opts =
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.merge(state: [])

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial_acc, reducer, _) do
    {:ok, acc} =
      Instance.stream_token_instances_with_unfetched_media_type(initial_acc, fn data, acc ->
        reducer.(data, acc)
      end)

    acc
  end

  @impl BufferedTask
  def run(token_instances, _) when is_list(token_instances) do
    ids =
      Enum.map(token_instances, fn %{contract_address_hash: address_hash, token_id: token_id} ->
        {token_id, address_hash.bytes}
      end)

    instances =
      Instance
      |> where([i], ^QueryHelper.tuple_in([:token_id, :token_contract_address_hash], ids))
      |> Repo.all()

    updates =
      instances
      |> Enum.filter(& &1.metadata)
      |> Enum.map(fn instance ->
        image_url = Instance.get_image_url_from_metadata(instance.metadata)
        animation_url = Instance.get_animation_url_from_metadata(instance.metadata)

        %{
          token_contract_address_hash: instance.token_contract_address_hash,
          token_id: instance.token_id,
          image_type: Helper.determine_media_type(image_url),
          animation_type: Helper.determine_media_type(animation_url)
        }
      end)

    Instance.batch_update_media_types(updates)

    :ok
  end

  defp defaults do
    [
      flush_interval: :infinity,
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency],
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size],
      task_supervisor: __MODULE__.TaskSupervisor
    ]
  end
end
