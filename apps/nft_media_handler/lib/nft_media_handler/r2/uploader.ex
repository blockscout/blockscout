defmodule NFTMediaHandler.R2.Uploader do
  @moduledoc """
  Uploads an image to R2/S3
  """

  @spec upload_image(binary(), binary(), binary()) :: {:error, any()} | {:ok, any(), nonempty_binary()}
  def upload_image(file_binary, file_name, r2_folder) do
    r2_config = Application.get_env(:ex_aws, :s3)
    file_path = Path.join(r2_folder, file_name)

    with %ExAws.Operation.S3{} = request <- ExAws.S3.put_object(r2_config[:bucket_name], file_path, file_binary),
         {:ok, result} <- ExAws.request(request) do
      uri = r2_config[:public_r2_url] |> URI.parse() |> URI.append_path(file_path) |> URI.to_string()
      {:ok, result, uri}
    end
  end
end
