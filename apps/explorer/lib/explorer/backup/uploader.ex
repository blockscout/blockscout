defmodule Explorer.Backup.Uploader do
  @moduledoc """
  Upload and Download files to an object storage
  """

  alias ExAws.S3
  alias ExAws.S3.Upload

  @doc """
  Downloads to /tmp a file from an object storage compatible with the Amazon S3 API
  """
  # sobelow_skip ["Traversal"]
  def download_file(file_name) do
    bucket()
    |> S3.download_file(network() <> "/" <> file_name, "/tmp/" <> file_name)
    |> ExAws.request!()

    file_name
  end

  @doc """
  Uploads a file on /tmp to an object storage compatible with the Amazon S3 API
  """
  # sobelow_skip ["Traversal"]
  def upload_file(file_name) do
    ("/tmp/" <> file_name)
    |> Upload.stream_file()
    |> S3.upload(bucket(), network() <> "/" <> file_name)
    |> ExAws.request!()

    file_name
  end

  defp network do
    Application.get_env(:explorer, __MODULE__)[:network]
  end

  defp bucket do
    Application.get_env(:explorer, __MODULE__)[:dump_bucket]
  end
end
