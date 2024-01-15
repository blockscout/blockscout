defmodule Indexer.Fetcher.Beacon.Client do
  @moduledoc """
    HTTP Client for Beacon Chain RPC
  """
  alias HTTPoison.Response
  require Logger

  @request_error_msg "Error while sending request to beacon rpc"

  def http_get_request(url) do
    case HTTPoison.get(url) do
      {:ok, %Response{body: body, status_code: 200}} ->
        Jason.decode(body)

      {:ok, %Response{body: body, status_code: _}} ->
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

  def get_blob_sidecars(slots) when is_list(slots) do
    {oks, errors_with_retries} =
      slots
      |> Enum.map(&get_blob_sidecars/1)
      |> Enum.with_index()
      |> Enum.map(&first_if_ok/1)
      |> Enum.split_with(&successful?/1)

    {errors, retries} = errors_with_retries |> Enum.unzip()

    if !Enum.empty?(errors) do
      Logger.error(fn ->
        [
          "Errors while fetching blob sidecars (failed for #{Enum.count(errors)}/#{Enum.count(slots)}) from beacon rpc: ",
          inspect(Enum.take(errors, 3), limit: :infinity, printable_limit: :infinity)
        ]
      end)
    end

    {:ok, oks |> Enum.map(fn {_, blob} -> blob end), retries}
  end

  def get_blob_sidecars(slot) do
    http_get_request(blob_sidecars_url(slot))
  end

  defp first_if_ok({{:ok, _} = first, _}), do: first
  defp first_if_ok(res), do: res

  defp successful?({:ok, _}), do: true
  defp successful?(_), do: false

  def get_header(slot) do
    http_get_request(header_url(slot))
  end

  def blob_sidecars_url(slot), do: "#{base_url()}" <> "/eth/v1/beacon/blob_sidecars/" <> to_string(slot)

  def header_url(slot), do: "#{base_url()}" <> "/eth/v1/beacon/headers/" <> to_string(slot)

  def base_url do
    Application.get_env(:indexer, Indexer.Fetcher.Beacon)[:beacon_rpc]
  end
end
