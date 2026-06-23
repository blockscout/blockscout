# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Hash.Trimmed do
  @moduledoc """
  A 32-byte hash that is stored in the database without leading zero bytes.

  This type keeps the public representation compatible with `Explorer.Chain.Hash.Full`: values are cast and loaded
  as 32-byte hashes, but dumped to the database in a compact `bytea` format with leading zero bytes removed.
  """

  alias Explorer.Chain.Hash
  alias Explorer.Chain.Hash.Full

  use Ecto.Type

  @byte_count 32
  @hexadecimal_digit_count Hash.hexadecimal_digits_per_byte() * @byte_count

  @typedoc """
  A #{@byte_count}-byte hash stored in the database without leading zero bytes.
  """
  @type t :: %Hash{byte_count: unquote(@byte_count), bytes: <<_::unquote(@byte_count * Hash.bits_per_byte())>>}

  @doc """
  Casts `term` to `t:t/0` using `Explorer.Chain.Hash.Full.cast/1`.

  If the `term` is already in `t:t/0`, then it is returned.

      iex> Explorer.Chain.Hash.Trimmed.cast(
      ...>   %Explorer.Chain.Hash{
      ...>     byte_count: 32,
      ...>     bytes: <<0x00000000000000000000000000000000000000000000000000000000000000ff ::
      ...>              big-integer-size(32)-unit(8)>>
      ...>   }
      ...> )
      {
        :ok,
        %Explorer.Chain.Hash{
          byte_count: 32,
          bytes: <<0x00000000000000000000000000000000000000000000000000000000000000ff :: big-integer-size(32)-unit(8)>>
        }
      }

  If the `term` is a `String.t` that starts with `0x`, then it is converted to `t:t/0`.

      iex> Explorer.Chain.Hash.Trimmed.cast("0x00000000000000000000000000000000000000000000000000000000000000ff")
      {
        :ok,
        %Explorer.Chain.Hash{
          byte_count: 32,
          bytes: <<0x00000000000000000000000000000000000000000000000000000000000000ff :: big-integer-size(32)-unit(8)>>
        }
      }

  `String.t` format must always have #{@hexadecimal_digit_count} hexadecimal digits after the `0x` base prefix.

      iex> Explorer.Chain.Hash.Trimmed.cast("0xff")
      :error

  """
  @impl Ecto.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(term), do: Full.cast(term)

  @doc """
  Dumps the hash to compact `:binary` (`bytea`) format used in database.

  Leading zero bytes are removed before storing the value.

      iex> Explorer.Chain.Hash.Trimmed.dump(
      ...>   %Explorer.Chain.Hash{
      ...>     byte_count: 32,
      ...>     bytes: <<0x00000000000000000000000000000000000000000000000000000000000000ff ::
      ...>              big-integer-size(32)-unit(8)>>
      ...>   }
      ...> )
      {:ok, <<0xff>>}

  A zero hash is stored as an empty binary.

      iex> Explorer.Chain.Hash.Trimmed.dump(
      ...>   %Explorer.Chain.Hash{
      ...>     byte_count: 32,
      ...>     bytes: <<0::256>>
      ...>   }
      ...> )
      {:ok, <<>>}

  If the field from the struct is an incorrect format such as `t:Explorer.Chain.Hash.Address.t/0`, `:error` is returned.

      iex> Explorer.Chain.Hash.Trimmed.dump(
      ...>   %Explorer.Chain.Hash{
      ...>     byte_count: 20,
      ...>     bytes: <<0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed :: big-integer-size(20)-unit(8)>>
      ...>   }
      ...> )
      :error

  """
  @impl Ecto.Type
  @spec dump(term()) :: {:ok, binary()} | :error
  def dump(%Hash{byte_count: @byte_count, bytes: bytes}) do
    {:ok, trim_leading_zeroes(bytes)}
  end

  def dump(term), do: Full.dump(term)

  @doc """
  Loads the compact binary hash from the database.

  The binary is left-padded with zero bytes up to #{@byte_count} bytes and loaded as `Explorer.Chain.Hash.Full`.

      iex> Explorer.Chain.Hash.Trimmed.load(<<0xff>>)
      {
        :ok,
        %Explorer.Chain.Hash{
          byte_count: 32,
          bytes: <<0x00000000000000000000000000000000000000000000000000000000000000ff :: big-integer-size(32)-unit(8)>>
        }
      }

  An empty binary is loaded as a zero hash.

      iex> Explorer.Chain.Hash.Trimmed.load(<<>>)
      {
        :ok,
        %Explorer.Chain.Hash{
          byte_count: 32,
          bytes: <<0::256>>
        }
      }

  If the binary hash is longer than #{@byte_count} bytes, `:error` is returned.

      iex> Explorer.Chain.Hash.Trimmed.load(<<0::264>>)
      :error

  """
  @impl Ecto.Type
  @spec load(term()) :: {:ok, t()} | :error
  def load(bytes) when is_binary(bytes) and byte_size(bytes) <= @byte_count do
    padding_size = @byte_count - byte_size(bytes)
    padded = <<0::size(padding_size)-unit(8), bytes::binary>>

    Full.load(padded)
  end

  def load(_), do: :error

  @doc """
  The underlying database type: `binary`. `binary` is used because stored values have variable byte length.
  """
  @impl Ecto.Type
  @spec type() :: :binary
  def type, do: :binary

  defp trim_leading_zeroes(<<0, rest::binary>>), do: trim_leading_zeroes(rest)

  defp trim_leading_zeroes(bytes), do: bytes
end
