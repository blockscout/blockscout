defmodule Explorer.Migrator.BackfillMetadataURL do
  @moduledoc """
  Backfills the metadata_url field for token instances
  """

  use Explorer.Migrator.FillingMigration, skip_meta_update?: true
  import Ecto.Query

  alias EthereumJSONRPC.NFT
  alias Explorer.{Chain, MetadataURIValidator, Repo}
  alias Explorer.Chain.Token.Instance
  alias Explorer.Migrator.FillingMigration

  require Logger

  @migration_name "backfill_metadata_url"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    tokens_address_hashes = ids |> Enum.map(&elem(&1, 0).bytes) |> Enum.uniq()
    tokens_address_hash_to_type = Map.take(state, tokens_address_hashes)
    tokens_address_hashes_to_preload_from_db = tokens_address_hashes -- Map.keys(tokens_address_hash_to_type)

    current_token_type_map =
      tokens_address_hashes_to_preload_from_db
      |> Chain.get_token_types()
      |> Enum.map(fn {address_hash, type} -> {address_hash.bytes, type} end)
      |> Enum.into(%{})
      |> Map.merge(tokens_address_hash_to_type)

    {ids
     |> Enum.map(fn {token_address_hash, token_id} ->
       {token_address_hash, token_id, current_token_type_map[token_address_hash.bytes]}
     end), Map.merge(state, current_token_type_map)}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    Instance
    |> where([instance], not is_nil(instance.metadata) and is_nil(instance.skip_metadata_url))
    |> select([instance], {instance.token_contract_address_hash, instance.token_id})
  end

  @impl FillingMigration
  def update_batch(token_instances) do
    now = DateTime.utc_now()

    prepared_params =
      token_instances
      |> NFT.batch_metadata_url_request(Application.get_env(:explorer, :json_rpc_named_arguments))
      |> Enum.zip(token_instances)
      |> Enum.map(&process_result/1)
      |> Enum.map(&Map.merge(&1, %{updated_at: now, inserted_at: now}))

    {_, result} =
      Repo.insert_all(Instance, prepared_params,
        on_conflict: token_instance_on_conflict(),
        conflict_target: [:token_id, :token_contract_address_hash],
        returning: true
      )

    result
  end

  @impl FillingMigration
  def update_cache do
    :ignore
  end

  # leave metadata url as empty string for errored requests in order to mark them somehow
  defp process_result({{{:error, reason}, _}, {token_contract_address_hash, token_id, _token_type}}) do
    Logger.error(
      "Error while fetching metadata URL for {#{token_contract_address_hash}, #{token_id}}: #{inspect(reason)}"
    )

    %{
      token_contract_address_hash: token_contract_address_hash,
      token_id: token_id,
      metadata_url: "",
      skip_metadata_url: false
    }
  end

  # credo:disable-for-next-line /Complexity/
  defp process_result({{{:ok, [url]}, _}, {token_contract_address_hash, token_id, _token_type}}) do
    url = String.trim(url, "'")

    metadata_url_params =
      case URI.parse(url) do
        %URI{path: "data:application/json;utf8," <> _json} ->
          %{skip_metadata_url: true}

        %URI{path: "data:application/json," <> _json} ->
          %{skip_metadata_url: true}

        %URI{path: "data:application/json;base64," <> _json} ->
          %{skip_metadata_url: true}

        %URI{scheme: "ipfs"} ->
          %{skip_metadata_url: true}

        %URI{scheme: "ar"} ->
          %{skip_metadata_url: true}

        %URI{path: "/ipfs/" <> _resource_id} ->
          %{skip_metadata_url: true}

        %URI{path: "ipfs/" <> _resource_id} ->
          %{skip_metadata_url: true}

        %URI{scheme: scheme} when not is_nil(scheme) ->
          process_common_url(url)

        %URI{} ->
          if url !== "" do
            %{skip_metadata_url: true}
          else
            %{
              metadata_url: nil,
              skip_metadata_url: false,
              metadata: nil,
              error: "no uri",
              thumbnails: nil,
              media_type: nil,
              cdn_upload_error: nil
            }
          end
      end

    Map.merge(metadata_url_params, %{token_contract_address_hash: token_contract_address_hash, token_id: token_id})
  end

  defp process_common_url(url) do
    case MetadataURIValidator.validate_uri(url) do
      :ok ->
        %{metadata_url: url, skip_metadata_url: false}

      {:error, reason} ->
        %{
          metadata_url: nil,
          skip_metadata_url: false,
          metadata: nil,
          error: to_string(reason),
          thumbnails: nil,
          media_type: nil,
          cdn_upload_error: nil
        }
    end
  end

  defp token_instance_on_conflict do
    from(
      token_instance in Instance,
      update: [
        set: [
          skip_metadata_url: fragment("EXCLUDED.skip_metadata_url"),
          metadata_url: fragment("EXCLUDED.metadata_url"),
          error:
            fragment(
              """
              CASE
              WHEN EXCLUDED.error IS NOT NULL THEN
                EXCLUDED.error
              ELSE
              ?
              END
              """,
              token_instance.error
            ),
          metadata:
            fragment(
              """
              CASE
              WHEN EXCLUDED.error IS NOT NULL THEN
                NULL
              ELSE
              ?
              END
              """,
              token_instance.metadata
            ),
          thumbnails:
            fragment(
              """
              CASE
              WHEN EXCLUDED.error IS NOT NULL THEN
                NULL
              ELSE
              ?
              END
              """,
              token_instance.thumbnails
            ),
          media_type:
            fragment(
              """
              CASE
              WHEN EXCLUDED.error IS NOT NULL THEN
                NULL
              ELSE
              ?
              END
              """,
              token_instance.media_type
            ),
          cdn_upload_error:
            fragment(
              """
              CASE
              WHEN EXCLUDED.error IS NOT NULL THEN
                NULL
              ELSE
              ?
              END
              """,
              token_instance.cdn_upload_error
            ),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", token_instance.updated_at)
        ]
      ]
    )
  end
end
