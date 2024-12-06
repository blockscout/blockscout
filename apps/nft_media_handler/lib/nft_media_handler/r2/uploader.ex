defmodule NFTMediaHandler.R2.Uploader do
  @moduledoc """
  Uploads an image to R2/S3
  """
  alias ExAws.S3

  @doc """
  Uploads an image to the specified destination.

  ## Parameters

    - `file_binary` (binary): The binary data of the image to be uploaded.
    - `file_name` (binary): The name of the image file in the R2 bucket.
    - `r2_folder` (binary): The folder in the R2 bucket where the image will be stored.

  ## Returns

    - `{:ok, result}`: If the upload is successful, returns a tuple with `:ok` and the result.
    - `{:error, reason}`: If the upload fails, returns a tuple with `:error` and the reason for the failure.
  """
  @spec upload_image(binary(), binary(), binary()) :: {:error, any()} | {:ok, any()}
  def upload_image(file_binary, file_name, r2_folder) do
    r2_config = Application.get_env(:ex_aws, :s3)
    file_path = Path.join(r2_folder, file_name)

    r2_config[:bucket_name]
    |> S3.put_object(file_path, file_binary)
    |> ExAws.request()
  end
end
