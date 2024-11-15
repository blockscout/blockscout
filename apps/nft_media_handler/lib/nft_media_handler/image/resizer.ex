defmodule NFTMediaHandler.Image.Resizer do
  @moduledoc """
  Resizes an image
  """

  @sizes [{60, "60x60"}, {250, "250x250"}, {500, "500x500"}]
  require Logger

  def resize(image, url, extension) do
    max_size = max(Image.width(image), Image.height(image) / Image.pages(image))

    @sizes
    |> Enum.map(fn {int_size, size} ->
      new_file_name = generate_file_name(url, extension, size)

      with {:size, true} <- {:size, max_size > int_size},
           {:ok, resized_image} <- Image.thumbnail(image, size, []),
           {:ok, binary} <- NFTMediaHandler.image_to_binary(resized_image, new_file_name, extension) do
        {int_size, binary, new_file_name}
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
    uid = :sha |> :crypto.hash(url) |> Base.encode16(case: :lower)
    "#{uid}_#{size}#{extension}"
  end
end
