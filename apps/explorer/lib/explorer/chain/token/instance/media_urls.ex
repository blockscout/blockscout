defmodule Explorer.Chain.Token.Instance.Thumbnails do
  @moduledoc """
  Module defines thumbnails type for token instances
  """
  use Ecto.Type

  @type t :: {String.t(), [integer()], boolean()}

  def type, do: :map

  def cast([file_path, sizes, original_uploaded?])
      when is_binary(file_path) and is_list(sizes) and is_boolean(original_uploaded?) do
    if Enum.all?(sizes, &is_integer/1) do
      {:ok, [file_path, sizes, original_uploaded?]}
    else
      :error
    end
  end

  def cast(_), do: :error

  def load([file_path, sizes, original_uploaded?]) do
    uri =
      Application.get_env(:ex_aws, :s3)[:public_r2_url] |> URI.parse() |> URI.append_path(file_path) |> URI.to_string()

    thumbnails =
      sizes
      |> Enum.map(fn size ->
        key = "#{size}x#{size}"
        {key, String.replace(uri, "{}", key)}
      end)
      |> Enum.into(%{})

    {:ok,
     if original_uploaded? do
       key = "original"
       Map.put(thumbnails, key, String.replace(uri, "{}", key))
     else
       thumbnails
     end}
  end

  def load(_), do: :error

  def dump([file_path, sizes, original_uploaded?])
      when is_binary(file_path) and is_list(sizes) and is_boolean(original_uploaded?) do
    {:ok, [file_path, sizes, original_uploaded?]}
  end

  def dump(_), do: :error
end
