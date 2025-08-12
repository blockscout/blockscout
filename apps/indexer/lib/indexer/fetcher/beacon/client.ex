defmodule Indexer.Fetcher.Beacon.Client do
  @moduledoc """
    HTTP Client for Beacon Chain RPC
  """
  require Logger

  alias Explorer.HttpClient

  @request_error_msg "Error while sending request to beacon rpc"

  def http_get_request(url) do
    case HttpClient.get(url) do
      {:ok, %{body: body, status_code: 200}} ->
        Jason.decode(body)

      {:ok, %{body: body, status_code: _}} ->
        {:error, body}

      {:error, error} ->
        old_truncate = Application.get_env(:logger, :truncate)
        Logger.configure(truncate: :infinity)

        Logger.error(fn ->
          [
            "Error while sending request to beacon rpc: #{url}: ",
            inspect(error, limit: :infinity, printable_limit: :infinity)
          ]
        end)

        Logger.configure(truncate: old_truncate)
        {:error, @request_error_msg}
    end
  end

  @doc """
  Fetches blob sidecars for multiple given beacon `slots` from the beacon RPC.

  Returns `{:ok, blob_sidecars_list, retry_indices_list}`
  where `retry_indices_list` is the list of indices from `slots` for which the request failed and should be retried.
  """
  @spec get_blob_sidecars([integer()]) :: {:ok, list(), [integer()]}
  def get_blob_sidecars([]), do: {:ok, [], []}

  def get_blob_sidecars(slots) when is_list(slots) do
    {oks, errors_with_retries} =
      slots
      |> Enum.map(&get_blob_sidecars/1)
      |> Enum.with_index()
      |> Enum.map(&first_if_ok/1)
      |> Enum.split_with(&successful?/1)

    {errors, retries} = errors_with_retries |> Enum.unzip()

    if not Enum.empty?(errors) do
      Logger.error(fn ->
        [
          "Errors while fetching blob sidecars (failed for #{Enum.count(errors)}/#{Enum.count(slots)}) from beacon rpc: ",
          inspect(Enum.take(errors, 3), limit: :infinity, printable_limit: :infinity)
        ]
      end)
    end

    {:ok, oks |> Enum.map(fn {_, blob} -> blob end), retries}
  end

  @spec get_blob_sidecars(integer()) :: {:error, any()} | {:ok, any()}
  def get_blob_sidecars(slot) do
    http_get_request(blob_sidecars_url(slot))
  end

  defp first_if_ok({{:ok, _} = first, _}), do: first
  defp first_if_ok(res), do: res

  defp successful?({:ok, _}), do: true
  defp successful?(_), do: false

  @spec get_header(integer()) :: {:error, any()} | {:ok, any()}
  def get_header(slot) do
    http_get_request(header_url(slot))
  end

  def blob_sidecars_url(slot), do: "#{base_url()}" <> "/eth/v1/beacon/blob_sidecars/" <> to_string(slot)

  def header_url(slot), do: "#{base_url()}" <> "/eth/v1/beacon/headers/" <> to_string(slot)

  def base_url do
    Application.get_env(:indexer, Indexer.Fetcher.Beacon)[:beacon_rpc]
  end
end
