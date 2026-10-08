# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.Beacon.Client do
  @moduledoc """
    HTTP Client for Beacon Chain RPC
  """
  require Logger

  alias Explorer.HttpClient

  @request_error_msg "Error while sending request to beacon rpc"

  @typedoc """
  A blob normalized to the same shape regardless of the beacon API endpoint it came from.

  `kzg_proof` is `nil` when the blob was taken from `/eth/v1/beacon/blobs`, which carries no
  single-blob KZG proofs (they were replaced by cell proofs since the Fulu fork).
  """
  @type blob_item :: %{
          blob: String.t(),
          kzg_commitment: String.t(),
          kzg_proof: String.t() | nil
        }

  defp http_get_request(url) do
    case HttpClient.get(url, [], recv_timeout: 30_000) do
      {:ok, %{body: body, status_code: 200}} ->
        Utils.JSON.decode(body)

      {:ok, %{body: body, status_code: status}} ->
        {:error, {status, body}}

      {:error, error} ->
        Logger.error(fn ->
          [
            "Error while sending request to beacon rpc: #{url}: ",
            inspect(error)
          ]
        end)

        {:error, @request_error_msg}
    end
  end

  @doc """
  Fetches blobs for multiple given beacon `slots` from the beacon RPC. See `get_blobs/1` for the
  per-slot logic (`/eth/v1/beacon/blobs` first, `/eth/v1/beacon/blob_sidecars` as a fallback).

  Returns `{:ok, blobs_per_slot, retry_indices_list}` where `blobs_per_slot` is a list of
  `t:blob_item/0` lists (one list per successfully fetched slot) and `retry_indices_list` is the
  list of indices from `slots` for which the request failed and should be retried.
  """
  @spec get_blobs_batch([integer()]) :: {:ok, [[blob_item()]], [integer()]}
  def get_blobs_batch([]), do: {:ok, [], []}

  def get_blobs_batch(slots) when is_list(slots) do
    {oks, errors_with_retries} =
      slots
      |> Enum.map(&get_blobs/1)
      |> Enum.with_index()
      |> Enum.map(&first_if_ok/1)
      |> Enum.split_with(&successful?/1)

    {errors, retries} = errors_with_retries |> Enum.unzip()

    if not Enum.empty?(errors) do
      Logger.error(fn ->
        [
          "Errors while fetching blobs (failed for #{Enum.count(errors)}/#{Enum.count(slots)}) from beacon rpc: ",
          inspect(Enum.take(errors, 3), limit: :infinity, printable_limit: :infinity)
        ]
      end)
    end

    {:ok, oks |> Enum.map(fn {_, blobs} -> blobs end), retries}
  end

  @doc """
  Fetches blobs of the given beacon `slot`.

  The `/eth/v1/beacon/blobs/{slot}` endpoint is tried first. It returns the raw blobs only (a list of
  hex strings), so the KZG commitments are taken from the block (`/eth/v2/beacon/blocks/{slot}`): from
  the execution payload bid for Gloas blocks or from the block body for Deneb..Fulu blocks. Blobs are
  returned by the beacon node in the order of the commitments, so they are zipped by index.

  If the `blobs` endpoint fails (e.g. the beacon node doesn't support it yet), the deprecated
  `/eth/v1/beacon/blob_sidecars/{slot}` endpoint is used instead. Note that `blob_sidecars` cannot
  serve Gloas blocks since their commitments are not part of the block body anymore.

  Returns `{:ok, [blob_item]}` or `{:error, reason}`.
  """
  @spec get_blobs(integer()) :: {:ok, [blob_item()]} | {:error, any()}
  def get_blobs(slot) do
    case http_get_request(blobs_url(slot)) do
      {:ok, %{"data" => blobs}} when is_list(blobs) ->
        with {:ok, commitments} <- get_blob_kzg_commitments(slot) do
          zip_blobs_with_commitments(slot, blobs, commitments)
        end

      {:ok, unexpected} ->
        {:error, {:unexpected_blobs_response, slot, unexpected}}

      {:error, reason} ->
        Logger.debug(fn ->
          "Cannot get blobs for slot #{slot} from the blobs endpoint (#{inspect(reason)}). Falling back to blob_sidecars."
        end)

        get_blob_sidecars_normalized(slot)
    end
  end

  @doc """
  Fetches the raw `/eth/v1/beacon/blob_sidecars/{slot}` response for the given `slot`.
  """
  @spec get_blob_sidecars(integer()) :: {:error, any()} | {:ok, any()}
  def get_blob_sidecars(slot) do
    http_get_request(blob_sidecars_url(slot))
  end

  @doc """
  Fetches the KZG commitments of the blobs included into the block at the given `slot`.

  Gloas blocks keep the commitments in the execution payload bid
  (`body.signed_execution_payload_bid.message.blob_kzg_commitments`), earlier forks keep them
  directly in the block body (`body.blob_kzg_commitments`).
  """
  @spec get_blob_kzg_commitments(integer()) :: {:ok, [String.t()]} | {:error, any()}
  def get_blob_kzg_commitments(slot) do
    case http_get_request(block_url(slot)) do
      {:ok, %{"data" => %{"message" => %{"body" => body}}}} ->
        extract_blob_kzg_commitments(body)

      {:ok, unexpected} ->
        {:error, {:unexpected_block_response, slot, unexpected}}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Extracts blob KZG commitments from a decoded beacon block body.
  """
  @spec extract_blob_kzg_commitments(map()) :: {:ok, [String.t()]} | {:error, :blob_kzg_commitments_not_found}
  def extract_blob_kzg_commitments(%{
        "signed_execution_payload_bid" => %{"message" => %{"blob_kzg_commitments" => commitments}}
      })
      when is_list(commitments),
      do: {:ok, commitments}

  def extract_blob_kzg_commitments(%{"blob_kzg_commitments" => commitments}) when is_list(commitments),
    do: {:ok, commitments}

  def extract_blob_kzg_commitments(_), do: {:error, :blob_kzg_commitments_not_found}

  defp zip_blobs_with_commitments(slot, blobs, commitments) when length(blobs) == length(commitments) do
    blobs
    |> Enum.zip(commitments)
    |> map_items(fn
      {item, commitment} when is_binary(commitment) ->
        with {:ok, blob} <- blob_from_blobs_item(item) do
          {:ok, %{blob: blob, kzg_commitment: commitment, kzg_proof: nil}}
        end

      {_item, _commitment} ->
        {:error, :malformed_blob_kzg_commitment}
    end)
    |> case do
      {:ok, _} = ok -> ok
      {:error, reason} -> {:error, {reason, slot}}
    end
  end

  defp zip_blobs_with_commitments(slot, blobs, commitments) do
    {:error, {:blob_count_mismatch, slot, length(blobs), length(commitments)}}
  end

  @doc """
  Extracts the blob hex string from an item of the `data` list returned by `/eth/v1/beacon/blobs/{slot}`.

  The spec defines the items as plain hex strings, but a wrapped form (`{"blob": "0x..."}`) is accepted too.

  Returns `{:ok, blob}` or `{:error, :malformed_blobs_item}` for an item of unexpected shape.
  """
  @spec blob_from_blobs_item(any()) :: {:ok, String.t()} | {:error, :malformed_blobs_item}
  def blob_from_blobs_item(blob) when is_binary(blob), do: {:ok, blob}
  def blob_from_blobs_item(%{"blob" => blob}) when is_binary(blob), do: {:ok, blob}
  def blob_from_blobs_item(_), do: {:error, :malformed_blobs_item}

  defp get_blob_sidecars_normalized(slot) do
    case get_blob_sidecars(slot) do
      {:ok, %{"data" => sidecars}} when is_list(sidecars) ->
        case map_items(sidecars, &normalize_blob_sidecar/1) do
          {:ok, _} = ok -> ok
          {:error, reason} -> {:error, {reason, slot}}
        end

      {:ok, unexpected} ->
        {:error, {:unexpected_blob_sidecars_response, slot, unexpected}}

      {:error, _} = error ->
        error
    end
  end

  defp normalize_blob_sidecar(%{"blob" => blob, "kzg_commitment" => commitment} = sidecar)
       when is_binary(blob) and is_binary(commitment) do
    case Map.get(sidecar, "kzg_proof") do
      kzg_proof when is_nil(kzg_proof) or is_binary(kzg_proof) ->
        {:ok, %{blob: blob, kzg_commitment: commitment, kzg_proof: kzg_proof}}

      _ ->
        {:error, :malformed_blob_sidecar}
    end
  end

  defp normalize_blob_sidecar(_), do: {:error, :malformed_blob_sidecar}

  # Maps `items` with `fun` returning `{:ok, mapped_items}` or the first `{:error, reason}` returned by `fun`.
  defp map_items(items, fun) do
    items
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      case fun.(item) do
        {:ok, mapped} -> {:cont, {:ok, [mapped | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      error -> error
    end
  end

  defp first_if_ok({{:ok, _} = first, _}), do: first
  defp first_if_ok(res), do: res

  defp successful?({:ok, _}), do: true
  defp successful?(_), do: false

  @spec get_header(integer()) :: {:error, any()} | {:ok, any()}
  def get_header(slot) do
    http_get_request(header_url(slot))
  end

  @spec get_spec :: {:error, any()} | {:ok, any()}
  def get_spec do
    http_get_request(spec_url())
  end

  @spec get_pending_deposits(integer() | String.t()) :: {:error, any()} | {:ok, any()}
  def get_pending_deposits(slot) do
    http_get_request(pending_deposits_url(slot))
  end

  @doc """
  Builds the URL of the `/eth/v1/beacon/blobs/{slot}` endpoint. When `versioned_hashes` is not
  empty, only the blobs with the given versioned hashes are requested.
  """
  @spec blobs_url(integer(), [String.t()]) :: String.t()
  def blobs_url(slot, versioned_hashes \\ [])

  def blobs_url(slot, []), do: "#{base_url()}/eth/v1/beacon/blobs/#{slot}"

  def blobs_url(slot, versioned_hashes) when is_list(versioned_hashes),
    do: blobs_url(slot, []) <> "?versioned_hashes=" <> Enum.join(versioned_hashes, ",")

  def block_url(slot), do: "#{base_url()}/eth/v2/beacon/blocks/#{slot}"

  def blob_sidecars_url(slot), do: "#{base_url()}" <> "/eth/v1/beacon/blob_sidecars/" <> to_string(slot)

  def header_url(slot), do: "#{base_url()}" <> "/eth/v1/beacon/headers/" <> to_string(slot)

  defp pending_deposits_url(epoch), do: "#{base_url()}/eth/v1/beacon/states/#{epoch}/pending_deposits"

  defp spec_url, do: "#{base_url()}/eth/v1/config/spec"

  def base_url do
    Application.get_env(:indexer, Indexer.Fetcher.Beacon)[:beacon_rpc]
  end
end
