defmodule Explorer.Chain.CsvExport.AsyncHelper do
  @moduledoc """
  Async CSV export helper functions.
  """

  alias Explorer.Chain.CsvExport.Request, as: CsvExportRequest
  alias Explorer.HttpClient
  alias Tesla.Multipart

  require Logger

  @doc """
  Uploads a file to Gokapi.
  """
  # sobelow_skip ["Traversal.FileModule"]
  @spec upload_file(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, any()}
  def upload_file(file_path, filename, uuid) do
    file_size = File.stat!(file_path).size
    chunk_size = chunk_size()

    result =
      file_path
      |> File.stream!(chunk_size)
      |> Stream.with_index()
      |> Enum.reduce_while(:ok, fn {chunk, index}, _acc ->
        case upload_chunk(chunk, uuid, file_size, index * chunk_size) do
          :ok -> {:cont, :ok}
          {:error, _} = error -> {:halt, error}
        end
      end)

    case result do
      :ok -> complete_upload(uuid, filename, file_size)
      error -> error
    end
  after
    File.rm(file_path)
  end

  @doc """
  Actualizes a CSV export request. If the file exists on the gokapi server, returns the request. If the file does not exist, deletes the request and returns nil. If there is an error, logs the error and returns the request.

  ## Parameters

  - `request`: The CSV export request to actualize.

  ## Returns

  - The actualized CSV export request or nil if the request was deleted.
  """
  @spec actualize_csv_export_request(CsvExportRequest.t() | nil) :: CsvExportRequest.t() | nil
  def actualize_csv_export_request(%CsvExportRequest{file_id: nil} = request), do: request

  def actualize_csv_export_request(%CsvExportRequest{} = request) do
    case file_exists?(request.file_id) do
      {:ok, true} ->
        request

      {:ok, false} ->
        CsvExportRequest.delete(request.id)
        nil

      error ->
        Logger.error("Failed to check if file exists: #{inspect(error)}")
        request
    end
  end

  def actualize_csv_export_request(nil) do
    nil
  end

  @spec upload_chunk(binary(), String.t(), integer(), integer()) :: :ok | {:error, any()}
  defp upload_chunk(chunk, uuid, filesize, offset) do
    multipart =
      Multipart.new()
      |> Multipart.add_file_content(chunk, "chunk", name: "file")
      |> Multipart.add_field("uuid", uuid)
      |> Multipart.add_field("filesize", to_string(filesize))
      |> Multipart.add_field("offset", to_string(offset))

    body = multipart |> Multipart.body() |> Enum.to_list() |> IO.iodata_to_binary()

    case HttpClient.post(
           gokapi_chunk_upload_url(),
           body,
           [api_key_header(), {"Content-Type", "multipart/form-data; boundary=#{multipart.boundary}"}],
           []
         ) do
      {:ok, %{status_code: 200}} -> :ok
      {:ok, resp} -> {:error, {:unexpected_status, resp.status_code}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec complete_upload(String.t(), String.t(), integer(), String.t()) :: {:ok, String.t()} | {:error, any()}
  defp complete_upload(uuid, filename, filesize, content_type \\ "application/csv") do
    result =
      HttpClient.post(
        gokapi_chunk_complete_url(),
        nil,
        [
          api_key_header(),
          {"uuid", uuid},
          {"filename", filename},
          {"filesize", to_string(filesize)},
          {"contenttype", content_type},
          {"allowedDownloads", to_string(gokapi_upload_allowed_downloads())},
          {"expiryDays", to_string(gokapi_upload_expiry_days())},
          {"nonblocking", "false"}
        ],
        []
      )

    with {:ok, %{status_code: 200, body: body}} <- result,
         {:ok, %{"FileInfo" => %{"Id" => file_id}}} <- Jason.decode(body) do
      {:ok, file_id}
    else
      error -> {:error, error}
    end
  end

  @spec file_exists?(String.t()) :: {:ok, boolean()} | {:error, any()}
  defp file_exists?(file_id) do
    case HttpClient.get(gokapi_file_metadata_url(file_id), [api_key_header()], []) do
      {:ok, %{status_code: 200}} ->
        {:ok, true}

      {:ok, %{status_code: 404}} ->
        {:ok, false}

      error ->
        {:error, error}
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  @spec stream_to_temp_file(Enumerable.t(), String.t()) :: String.t()
  def stream_to_temp_file(stream, uuid) do
    tmp_dir = tmp_dir()
    file_path = Path.join(tmp_dir, "csv_export_#{uuid}.csv")
    File.mkdir_p!(tmp_dir)

    File.open!(file_path, [:write, :binary], fn file ->
      Enum.each(stream, &write_chunk(file, &1))
    end)

    file_path
  end

  defp write_chunk(file, chunk) do
    case :file.write(file, chunk) do
      :ok -> :ok
      {:error, reason} -> raise "Failed to write CSV chunk: #{inspect(reason)}"
    end
  end

  @spec max_pending_tasks_per_ip() :: integer()
  def max_pending_tasks_per_ip do
    csv_export_config()[:max_pending_tasks_per_ip]
  end

  @spec db_timeout() :: non_neg_integer()
  def db_timeout do
    csv_export_config()[:db_timeout]
  end

  @spec csv_export_config() :: list()
  defp csv_export_config do
    Application.get_env(:explorer, Explorer.Chain.CsvExport)
  end

  @spec chunk_size() :: integer()
  defp chunk_size do
    csv_export_config()[:chunk_size]
  end

  @spec tmp_dir() :: String.t()
  defp tmp_dir do
    csv_export_config()[:tmp_dir]
  end

  @spec gokapi_url() :: String.t()
  defp gokapi_url do
    csv_export_config()[:gokapi_url] <> "/api"
  end

  @spec gokapi_api_key() :: String.t()
  defp gokapi_api_key do
    csv_export_config()[:gokapi_api_key]
  end

  @spec gokapi_upload_expiry_days() :: integer()
  defp gokapi_upload_expiry_days do
    csv_export_config()[:gokapi_upload_expiry_days]
  end

  @spec gokapi_upload_allowed_downloads() :: integer()
  defp gokapi_upload_allowed_downloads do
    csv_export_config()[:gokapi_upload_allowed_downloads]
  end

  @spec gokapi_chunk_upload_url() :: String.t()
  defp gokapi_chunk_upload_url do
    "#{gokapi_chunk_url()}/add"
  end

  @spec gokapi_chunk_complete_url() :: String.t()
  defp gokapi_chunk_complete_url do
    "#{gokapi_chunk_url()}/complete"
  end

  @spec gokapi_chunk_url() :: String.t()
  defp gokapi_chunk_url do
    "#{gokapi_url()}/chunk"
  end

  @spec gokapi_file_metadata_url(String.t()) :: String.t()
  defp gokapi_file_metadata_url(file_id) do
    "#{gokapi_url()}/files/list/#{file_id}"
  end

  @spec api_key_header() :: {String.t(), String.t()}
  defp api_key_header do
    {"apikey", gokapi_api_key()}
  end
end
