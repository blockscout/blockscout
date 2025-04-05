defmodule NFTMediaHandler do
  @moduledoc """
  Module resizes and uploads images to R2/S3 bucket.
  """

  require Logger

  alias Explorer.Token.MetadataRetriever, as: TokenMetadataRetriever
  alias Image.Video
  alias NFTMediaHandler.Image.Resizer
  alias NFTMediaHandler.Media.Fetcher
  alias NFTMediaHandler.R2.Uploader
  alias Vix.Vips.Image, as: VipsImage

  @doc """
  Prepares and uploads media by its URL.

  ## Parameters

    - url: The URL of the media to be prepared and uploaded.
    - r2_folder: The destination folder where the media will be uploaded in R2 bucket.

  ## Returns

    - :error if the preparation or upload fails.
    - A tuple containing a list of Explorer.Chain.Token.Instance.Thumbnails format and a tuple with content type if successful.
  """
  @spec prepare_and_upload_by_url(binary(), binary()) :: {:error, any()} | {list(), {binary(), binary()}}
  def prepare_and_upload_by_url(url, r2_folder) do
    with {prepared_url, headers} <- maybe_process_ipfs(url),
         {:fetch, {:ok, media_type, body}} <- {:fetch, Fetcher.fetch_media(prepared_url, headers)},
         {:ok, result} <- prepare_and_upload_inner(media_type, body, url, r2_folder) do
      result
    else
      {:fetch, {:error, reason}} ->
        Logger.warning("Error on fetching media: #{inspect(reason)}, from url (#{url})")
        {:error, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp prepare_and_upload_inner({"image", _} = media_type, initial_image_binary, url, r2_folder) do
    with {:image, {:ok, image}} <- {:image, Image.from_binary(initial_image_binary, pages: -1)},
         extension <- media_type_to_extension(media_type),
         thumbnails <- Resizer.resize(image, url, ".#{extension}"),
         {:original, {:ok, _result}} <-
           {:original,
            Uploader.upload_image(
              initial_image_binary,
              Resizer.generate_file_name(url, ".#{extension}", "original"),
              r2_folder
            )},
         {:thumbnails, {:ok, _result}} <- {:thumbnails, Uploader.upload_images(thumbnails, r2_folder)} do
      file_path = Path.join(r2_folder, Resizer.generate_file_name(url, ".#{extension}", "{}"))
      original_uploaded? = true
      uploaded_thumbnails_sizes = thumbnails |> Enum.map(&elem(&1, 0))
      {:ok, {[file_path, uploaded_thumbnails_sizes, original_uploaded?], media_type}}
    else
      {:image, {:error, reason}} ->
        Logger.warning("Error on open image from url (#{url}): #{inspect(reason)}")
        {:error, reason}

      {type, {:error, reason}} ->
        Logger.warning("Error on uploading #{type} image from url (#{url}): #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp prepare_and_upload_inner({"video", _} = media_type, body, url, r2_folder) do
    extension = media_type_to_extension(media_type)
    file_name = Resizer.generate_file_name(url, ".#{extension}", "original")
    path = "#{Application.get_env(:nft_media_handler, :tmp_dir)}#{file_name}"

    with {:file, :ok} <- {:file, File.write(path, body)},
         {:video, {:ok, image}} <-
           {:video,
            Video.with_video(path, fn video ->
              Video.image_from_video(video, frame: 0)
            end)},
         _ <- remove_file(path),
         thumbnails when thumbnails != [] <- image |> Resizer.resize(url, ".jpg"),
         {:thumbnails, {:ok, _result}} <- {:thumbnails, Uploader.upload_images(thumbnails, r2_folder)} do
      file_path = Path.join(r2_folder, Resizer.generate_file_name(url, ".jpg", "{}"))
      uploaded_thumbnails_sizes = thumbnails |> Enum.map(&elem(&1, 0))
      original_uploaded? = true

      {:ok, {[file_path, uploaded_thumbnails_sizes, original_uploaded?], media_type}}
    else
      {:file, reason} ->
        Logger.error("Error while writing video to file: #{inspect(reason)}, url: #{url}")
        {:error, reason}

      {:video, {:error, reason}} ->
        Logger.error("Error while taking zero frame from video: #{inspect(reason)}, url: #{url}")
        remove_file(path)
        {:error, reason}

      [] ->
        Logger.error("Error while resizing video: No thumbnails generated, url: #{url}")
        {:error, :no_thumbnails}

      {:thumbnails, {:error, reason}} ->
        Logger.error("Error while uploading video thumbnails: #{inspect(reason)}, url: #{url}")
        {:error, reason}
    end
  end

  defp media_type_to_extension({type, subtype}) do
    [extension | _] = MIME.extensions("#{type}/#{subtype}")
    extension
  end

  @doc """
  Converts an image to a binary format.

  ## Parameters

    - `image`: The `Vix.Vips.Image` struct representing the image to be converted.
    - `file_name`: used only for .gif.
    - `extension`: The extension of the image format.

  ## Returns

    - `:file_error` if there is an error related to file operations.
    - `{:error, reason}` if the conversion fails for any other reason.
    - `{:ok, binary}` if the conversion is successful, with the binary representing the image.
  """
  @spec image_to_binary(Vix.Vips.Image.t(), binary(), binary()) :: :file_error | {:error, any()} | {:ok, binary()}
  def image_to_binary(resized_image, _file_name, extension) when extension in [".jpg", ".png", ".webp"] do
    VipsImage.write_to_buffer(resized_image, "#{extension}[Q=70,strip]")
  end

  # workaround, because VipsImage.write_to_buffer/2 does not support .gif
  def image_to_binary(resized_image, file_name, ".gif") do
    path = "#{Application.get_env(:nft_media_handler, :tmp_dir)}#{file_name}"

    with :ok <- VipsImage.write_to_file(resized_image, path),
         {:ok, result} <- File.read(path) do
      remove_file(path)
      {:ok, result}
    else
      {:error, reason} ->
        Logger.error("Error while writing image to file: #{inspect(reason)}, path: #{path}")
        :file_error
    end
  end

  defp remove_file(path) do
    case File.rm(path) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("Unable to delete file, reason: #{inspect(reason)}, path: #{path}")
        :error
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp maybe_process_ipfs(uri) do
    case URI.parse(uri) do
      %URI{scheme: "ipfs", host: host, path: path} ->
        resource_id =
          with "ipfs" <- host,
               "/" <> resource_id <- path do
            resource_id
          else
            _ ->
              if is_nil(path), do: host, else: host <> path
          end

        {TokenMetadataRetriever.ipfs_link(resource_id), TokenMetadataRetriever.ipfs_headers()}

      %URI{scheme: "ar", host: _host, path: resource_id} ->
        {TokenMetadataRetriever.arweave_link(resource_id), TokenMetadataRetriever.ar_headers()}

      %URI{scheme: _, path: "/ipfs/" <> resource_id} ->
        {TokenMetadataRetriever.ipfs_link(resource_id), TokenMetadataRetriever.ipfs_headers()}

      %URI{scheme: _, path: "ipfs/" <> resource_id} ->
        {TokenMetadataRetriever.ipfs_link(resource_id), TokenMetadataRetriever.ipfs_headers()}

      %URI{scheme: scheme} when not is_nil(scheme) ->
        {uri, []}

      %URI{path: path} ->
        case path do
          "Qm" <> <<_::binary-size(44)>> = resource_id ->
            {TokenMetadataRetriever.ipfs_link(resource_id), TokenMetadataRetriever.ipfs_headers()}

          "bafybe" <> _ = resource_id ->
            {TokenMetadataRetriever.ipfs_link(resource_id), TokenMetadataRetriever.ipfs_headers()}

          _ ->
            {uri, []}
        end
    end
  end
end
