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

  @ipfs_protocol "ipfs://"

  @spec prepare_and_upload_by_url(binary(), binary()) :: :error | {map(), {binary(), binary()}}
  def prepare_and_upload_by_url(url, r2_folder) do
    with {prepared_url, headers} <- maybe_process_ipfs(url),
         {:ok, media_type, body} <- Fetcher.fetch_media(prepared_url, headers) do
      prepare_and_upload_inner(media_type, body, url, r2_folder)
    else
      {:error, reason} ->
        Logger.warning("Error on fetching media: #{inspect(reason)}, from url (#{url})")
        {:error, reason}
    end
  end

  def prepare_and_upload_inner({"image", _} = media_type, initial_image_binary, url, r2_folder) do
    case {:image, Image.from_binary(initial_image_binary, pages: -1)} do
      {:image, {:ok, image}} ->
        extension = media_type_to_extension(media_type)

        thumbnails = Resizer.resize(image, url, ".#{extension}")

        uploaded_thumbnails =
          thumbnails
          |> Enum.map(fn {size, image, file_name} ->
            # credo:disable-for-next-line
            case Uploader.upload_image(image, file_name, r2_folder) do
              {:ok, _result, uploaded_file_url} ->
                {size, uploaded_file_url}

              _ ->
                nil
            end
          end)
          |> Enum.reject(&is_nil/1)
          |> Enum.into(%{})

        uploaded_original_url =
          case Uploader.upload_image(
                 initial_image_binary,
                 Resizer.generate_file_name(url, ".#{extension}", "original"),
                 r2_folder
               ) do
            {:ok, _result, uploaded_file_url} ->
              uploaded_file_url

            _ ->
              nil
          end

        max_size_or_original =
          uploaded_original_url ||
            (
              {_, url} =
                Enum.max_by(uploaded_thumbnails, fn {size, _} ->
                  {int_size, _} = Integer.parse(size)
                  int_size
                end)

              url
            )

        result =
          Resizer.sizes()
          |> Enum.reduce(uploaded_thumbnails, fn {_, size}, acc ->
            Map.put_new(acc, size, max_size_or_original)
          end)
          |> Map.put("original", uploaded_original_url)

        {result, media_type}

      {:image, {:error, reason}} ->
        Logger.warning("Error on open image from url (#{url}): #{inspect(reason)}")
        :error
    end
  end

  def prepare_and_upload_inner({"video", _} = media_type, body, url, r2_folder) do
    extension = media_type_to_extension(media_type)
    file_name = Resizer.generate_file_name(url, ".#{extension}", "original")
    path = "#{Application.get_env(:nft_media_handler, :tmp_dir)}#{file_name}"

    with {:file, :ok} <- {:file, File.write(path, body)},
         {:ok, image} <-
           Video.with_video(path, fn video ->
             Video.image_from_video(video, frame: 0)
           end) do
      remove_file(path)
      thumbnails = Resizer.resize(image, url, ".jpg")

      result =
        thumbnails
        |> Enum.map(fn {size, image, file_name} ->
          case Uploader.upload_image(image, file_name, r2_folder) do
            {:ok, _result, uploaded_file_url} ->
              {size, uploaded_file_url}

            _ ->
              nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.into(%{})

      {result, media_type}
    else
      {:file, reason} ->
        Logger.error("Error while writing video to file: #{inspect(reason)}, url: #{url}")
        :error

      {:error, reason} ->
        Logger.error("Error while taking zero frame from video: #{inspect(reason)}, url: #{url}")
        File.rm(path)
        :error
    end
  end

  defp media_type_to_extension({type, subtype}) do
    [extension | _] = MIME.extensions("#{type}/#{subtype}")
    extension
  end

  def image_to_binary(resized_image, _file_name, extension) when extension in [".jpg", ".png", ".webp"] do
    VipsImage.write_to_buffer(resized_image, "#{extension}[Q=70,strip]")
  end

  # workaround, because VipsImage.write_to_buffer/2 does not support .gif
  def image_to_binary(resized_image, file_name, ".gif") do
    path = "#{Application.get_env(:nft_media_handler, :tmp_dir)}#{file_name}"

    with :ok <- VipsImage.write_to_file(resized_image, path),
         {:ok, result} <- File.read(path) do
      remove_file(path)
      result
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

  defp maybe_process_ipfs("#{@ipfs_protocol}ipfs/" <> right) do
    {TokenMetadataRetriever.ipfs_link(right), TokenMetadataRetriever.ipfs_headers()}
  end

  defp maybe_process_ipfs("ipfs/" <> right) do
    {TokenMetadataRetriever.ipfs_link(right), TokenMetadataRetriever.ipfs_headers()}
  end

  defp maybe_process_ipfs(@ipfs_protocol <> right) do
    {TokenMetadataRetriever.ipfs_link(right), TokenMetadataRetriever.ipfs_headers()}
  end

  defp maybe_process_ipfs("Qm" <> _ = result) do
    if String.length(result) == 46 do
      {TokenMetadataRetriever.ipfs_link(result), TokenMetadataRetriever.ipfs_headers()}
    else
      {result, []}
    end
  end

  defp maybe_process_ipfs(url) do
    {url, []}
  end
end
