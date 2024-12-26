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
  @spec upload_image(binary(), binary(), binary()) :: {:ok, any()} | {:error, any()}
  def upload_image(file_binary, file_name, r2_folder) do
    r2_config = Application.get_env(:ex_aws, :s3)
    file_path = Path.join(r2_folder, file_name)

    r2_config[:bucket_name]
    |> S3.put_object(file_path, file_binary)
    |> ExAws.request()
  end

  @doc """
  Uploads a list of images to the specified R2 folder.

  ## Parameters

    - images: A list of images to be uploaded.
    - r2_folder: The destination folder in R2 where the images will be uploaded.
  """
  @spec upload_images(list(), binary()) :: {:ok, any()} | {:error, any()}
  def upload_images(images, r2_folder) do
    Enum.reduce_while(images, {:ok, nil}, fn {_pixel_size, file_binary, file_name}, _acc ->
      case upload_image(file_binary, file_name, r2_folder) do
        {:ok, _} ->
          {:cont, {:ok, nil}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end
end
