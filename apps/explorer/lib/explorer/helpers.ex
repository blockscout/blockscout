defmodule Explorer.Helpers do
  @moduledoc """
  Auxiliary common functions.
  """

  alias ABI.TypeDecoder
  alias Explorer.Chain.Data

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
end
