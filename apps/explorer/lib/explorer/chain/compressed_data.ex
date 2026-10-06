# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.CompressedData do
  @moduledoc """
  Ecto type for storing `Explorer.Chain.Data` in LZ4-compressed `bytea` format.

  The Elixir-side representation is the same as `Explorer.Chain.Data.t/0`, while
  dumped database value is compressed binary data.
  """

  alias Explorer.Chain.Data

  use Ecto.Type

  @type t :: Data.t()

  @impl Ecto.Type
  @spec type() :: :binary
  def type, do: :binary

  @impl Ecto.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(term), do: Data.cast(term)

  @impl Ecto.Type
  @spec dump(term()) :: {:ok, binary()} | :error
  def dump(term) do
    with {:ok, data} <- Data.cast(term),
         {:ok, bytes} <- Data.dump(data) do
      {:ok, compress(bytes)}
    end
  end

  @impl Ecto.Type
  @spec load(term()) :: {:ok, t()} | :error
  def load(<<_::binary>> = compressed_bytes) do
    case decompress(compressed_bytes) do
      {:ok, bytes} -> Data.load(bytes)
      _ -> :error
    end
  end

  def load(_), do: :error

  defp compress(bytes) do
    <<byte_size(bytes)::32>> <> NimbleLZ4.compress(bytes)
  end

  defp decompress(<<uncompressed_size::32, compressed_binary::binary>>) do
    case NimbleLZ4.decompress(compressed_binary, uncompressed_size) do
      {:ok, bytes} when is_binary(bytes) -> {:ok, bytes}
      _ -> :error
    end
  end
end
