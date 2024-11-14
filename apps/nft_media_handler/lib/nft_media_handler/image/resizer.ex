defmodule NFTMediaHandler.Image.Resizer do
  @moduledoc """
  Resizes an image
  """

  @sizes [{60, "60x60"}, {250, "250x250"}, {500, "500x500"}]
  require Logger

  # {"60x60":
  # "https://pub-1f1ac54bb1ee4b1ab5f87ca95854800c.r2.dev/folder_1/64b4fc0d50f0a0c18953fafd8c92988b140c2ba8_{size}.jpg",

  # ["64b4fc0d50f0a0c18953fafd8c92988b140c2ba8_{size}.jpg", ["60x60", "250x250"]]

  # "250x250": "https://pub-1f1ac54bb1ee4b1ab5f87ca95854800c.r2.dev/folder_1/64b4fc0d50f0a0c18953fafd8c92988b140c2ba8_250x250.jpg",
  # "original": "https://pub-1f1ac54bb1ee4b1ab5f87ca95854800c.r2.dev/folder_1/64b4fc0d50f0a0c18953fafd8c92988b140c2ba8_original.jpg"}

  # optimize urls storage
  def resize(image, url, extension) do
    max_size = max(Image.width(image), Image.height(image) / Image.pages(image))

    @sizes
    |> Enum.map(fn {int_size, size} ->
      new_file_name = generate_file_name(url, extension, size)

      with {:size, true} <- {:size, max_size > int_size},
           {:ok, resized_image} <- Image.thumbnail(image, size, []),
           {:ok, binary} <- NFTMediaHandler.image_to_binary(resized_image, new_file_name, extension) do
        {size, binary, new_file_name}
      else
        {:size, _} ->
          Logger.debug("Skipped #{size} resizing due to small image size")
          nil

        error ->
          Logger.warning("Error while #{size} resizing: #{inspect(error)}")
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  def sizes, do: @sizes

  def generate_file_name(url, extension, size) do
    "#{:sha |> :crypto.hash(url) |> Base.encode16(case: :lower)}_#{size}#{extension}"
  end
end
