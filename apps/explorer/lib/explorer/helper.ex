defmodule Explorer.Helper do
  @moduledoc """
  Common explorer helper
  """

  alias ABI.TypeDecoder
  alias Explorer.Chain
  alias Explorer.Chain.Data

  import Ecto.Query, only: [where: 3]

  @spec decode_data(binary() | map(), list()) :: list() | nil
  def decode_data("0x", types) do
    for _ <- types, do: nil
  end

  def decode_data("0x" <> encoded_data, types) do
    decode_data(encoded_data, types)
  end

  def decode_data(%Data{} = data, types) do
    data
    |> Data.to_string()
    |> decode_data(types)
  end

  def decode_data(encoded_data, types) do
    encoded_data
    |> Base.decode16!(case: :mixed)
    |> TypeDecoder.decode_raw(types)
  end

  @spec parse_integer(binary() | nil) :: integer() | nil
  def parse_integer(nil), do: nil

  def parse_integer(string) do
    case Integer.parse(string) do
      {number, ""} -> number
      _ -> nil
    end
  end

  @doc """
    Function to preload a `struct` for each element of the `list`.
    You should specify a primary key for a `struct` in `references_field`,
    and the list element's foreign key in `foreign_key_field`.
    Results will be placed to `preload_field`
  """
  @spec custom_preload(list(map()), keyword(), atom(), atom(), atom(), atom()) :: list()
  def custom_preload(list, options, struct, foreign_key_field, references_field, preload_field) do
    to_fetch_from_db = list |> Enum.map(& &1[foreign_key_field]) |> Enum.uniq()

    associated_elements =
      struct
      |> where([t], field(t, ^references_field) in ^to_fetch_from_db)
      |> Chain.select_repo(options).all()
      |> Enum.reduce(%{}, fn el, acc -> Map.put(acc, Map.from_struct(el)[references_field], el) end)

    Enum.map(list, fn el -> Map.put(el, preload_field, associated_elements[el[foreign_key_field]]) end)
  end

  @doc """
  Decode json
  """
  @spec decode_json(any()) :: map() | list() | nil
  def decode_json(nil), do: nil

  def decode_json(data) do
    if String.valid?(data) do
      safe_decode_json(data)
    else
      data
      |> :unicode.characters_to_binary(:latin1)
      |> safe_decode_json()
    end
  end

  defp safe_decode_json(data) do
    case Jason.decode(data) do
      {:ok, decoded} -> decoded
      _ -> %{error: data}
    end
  end

  @doc """
    Tries to decode binary to json, return either decoded object, or initial binary
  """
  @spec maybe_decode(binary) :: any
  def maybe_decode(data) do
    case safe_decode_json(data) do
      %{error: _} -> data
      decoded -> decoded
    end
  end

  @doc """
  Checks if input is a valid URL
  """
  @spec validate_url(String.t() | nil) :: {:ok, String.t()} | :error
  def validate_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: nil} -> :error
      _ -> {:ok, url}
    end
  end

  def validate_url(_), do: :error

  @doc """
    Validate url
  """
  @spec valid_url?(String.t()) :: boolean
  def valid_url?(string) do
    uri = URI.parse(string)

    uri.scheme != nil && uri.host =~ "."
  end
end
