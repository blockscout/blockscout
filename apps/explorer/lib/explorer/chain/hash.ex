defmodule Explorer.Chain.Hash do
  @moduledoc """
  A [KECCAK-256](https://en.wikipedia.org/wiki/SHA-3) hash.
  """

  import Bitwise
  alias Poison.Encoder.BitString

  @bits_per_byte 8
  @hexadecimal_digits_per_byte 2
  @max_byte_count 32

  @derive Jason.Encoder
  defstruct ~w(byte_count bytes)a

  @typedoc """
  A full [KECCAK-256](https://en.wikipedia.org/wiki/SHA-3) hash is #{@max_byte_count}, but it can also be truncated to
  fewer bytes.
  """
  @type byte_count :: 1..unquote(@max_byte_count)

  @typedoc """
  A module that implements this behaviour's callbacks
  """
  @type t :: %__MODULE__{
          byte_count: byte_count,
          bytes: <<_::_*8>>
        }

  @callback byte_count() :: byte_count()

  @doc """
  Number of bits in a byte
  """
  def bits_per_byte, do: 8

  @doc """
  How many hexadecimal digits are used to represent a byte
  """
  def hexadecimal_digits_per_byte, do: 2

  @doc """
  Casts `term` to `t:t/0` using `c:byte_count/0` in `module`
  """
  @spec cast(module(), term()) :: {:ok, t()} | :error
  def cast(callback_module, term) when is_atom(callback_module) do
    byte_count = callback_module.byte_count()

    case term do
      %__MODULE__{byte_count: ^byte_count, bytes: <<_::big-integer-size(byte_count)-unit(@bits_per_byte)>>} = cast ->
        {:ok, cast}

      <<_::big-integer-size(byte_count)-unit(@bits_per_byte)>> ->
        {:ok, %__MODULE__{byte_count: byte_count, bytes: term}}

      <<"0x", hexadecimal_digits::binary>> ->
        cast_hexadecimal_digits(hexadecimal_digits, byte_count)

      integer when is_integer(integer) ->
        cast_integer(integer, byte_count)

      _ ->
        :error
    end
  end

  @doc """
  Dumps the `t` `bytes` to `:binary` (`bytea`) format used in database.
  """
  @spec dump(module(), term()) :: {:ok, binary} | :error
  def dump(callback_module, term) when is_atom(callback_module) do
    byte_count = callback_module.byte_count()

    case term do
      # ensure inconsistent `t` with a different `byte_count` from the `callback_module` isn't dumped to the database,
      # in case `%__MODULE__{}` is set in a field value directly
      %__MODULE__{byte_count: ^byte_count, bytes: <<_::big-integer-size(byte_count)-unit(@bits_per_byte)>> = bytes} ->
        {:ok, bytes}

      _ ->
        :error
    end
  end

  @doc """
  Loads the binary hash from the database into `t:t/0` if it has `c:byte_count/0` bytes from `callback_module`.
  """
  @spec load(module(), term()) :: {:ok, t} | :error
  def load(callback_module, term) do
    byte_count = callback_module.byte_count()

    case term do
      # ensure that only hashes of `byte_count` that matches `callback_module` can be loaded back from database to
      # prevent using `Ecto.Type` with wrong byte_count on a database column
      <<_::big-integer-size(byte_count)-unit(@bits_per_byte)>> ->
        {:ok, %__MODULE__{byte_count: byte_count, bytes: term}}

      _ ->
        :error
    end
  end

  @doc """
  Converts the `t:t/0` to the integer version of the hash

      iex> Explorer.Chain.Hash.to_integer(
      ...>   %Explorer.Chain.Hash{
      ...>     byte_count: 32,
      ...>     bytes: <<0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b ::
      ...>              big-integer-size(32)-unit(8)>>
      ...>   }
      ...> )
      0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b
      iex> Explorer.Chain.Hash.to_integer(
      ...>   %Explorer.Chain.Hash{
      ...>     byte_count: 20,
      ...>     bytes: <<0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed :: big-integer-size(20)-unit(8)>>
      ...>   }
      ...> )
      0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed

  """
  @spec to_integer(t()) :: pos_integer()
  def to_integer(%__MODULE__{byte_count: byte_count, bytes: bytes}) do
    <<integer::big-integer-size(byte_count)-unit(8)>> = bytes

    integer
  end

  @doc """
  Converts the `t:t/0` to `iodata` representation shown to users.

      iex> %Explorer.Chain.Hash{
      ...>   byte_count: 32,
      ...>   bytes: <<0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b ::
      ...>            big-integer-size(32)-unit(8)>>
      ...> } |>
      ...> Explorer.Chain.Hash.to_iodata() |>
      ...> IO.iodata_to_binary()
      "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b"

  Always pads number, so that it is a valid format for casting.

      iex> %Explorer.Chain.Hash{
      ...>   byte_count: 32,
      ...>   bytes: <<0x1234567890abcdef :: big-integer-size(32)-unit(8)>>
      ...> } |>
      ...> Explorer.Chain.Hash.to_iodata() |>
      ...> IO.iodata_to_binary()
      "0x0000000000000000000000000000000000000000000000001234567890abcdef"

  """
  @spec to_iodata(t) :: iodata()
  def to_iodata(%__MODULE__{byte_count: byte_count} = hash) do
    integer = to_integer(hash)
    hexadecimal_digit_count = byte_count_to_hexadecimal_digit_count(byte_count)
    unprefixed = :io_lib.format('~#{hexadecimal_digit_count}.16.0b', [integer])

    ["0x", unprefixed]
  end

  @doc """
  Converts the `t:t/0` to string representation shown to users.

      iex> Explorer.Chain.Hash.to_string(
      ...>   %Explorer.Chain.Hash{
      ...>     byte_count: 32,
      ...>     bytes: <<0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b ::
      ...>              big-integer-size(32)-unit(8)>>
      ...>   }
      ...> )
      "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b"

  Always pads number, so that it is a valid format for casting.

      iex> Explorer.Chain.Hash.to_string(
      ...>   %Explorer.Chain.Hash{
      ...>     byte_count: 32,
      ...>     bytes: <<0x1234567890abcdef :: big-integer-size(32)-unit(8)>>
      ...>   }
      ...> )
      "0x0000000000000000000000000000000000000000000000001234567890abcdef"

  """
  @spec to_string(t) :: String.t()
  def to_string(%__MODULE__{} = hash) do
    hash
    |> to_iodata()
    |> IO.iodata_to_binary()
  end

  defp byte_count_to_hexadecimal_digit_count(byte_count) do
    byte_count * @hexadecimal_digits_per_byte
  end

  defp byte_count_to_max_integer(byte_count) do
    (1 <<< (byte_count * @bits_per_byte + 1)) - 1
  end

  defp cast_hexadecimal_digits(hexadecimal_digits, byte_count) when is_binary(hexadecimal_digits) do
    hexadecimal_digit_count = byte_count_to_hexadecimal_digit_count(byte_count)

    with ^hexadecimal_digit_count <- String.length(hexadecimal_digits),
         {:ok, bytes} <- Base.decode16(hexadecimal_digits, case: :mixed) do
      {:ok, %__MODULE__{byte_count: byte_count, bytes: bytes}}
    else
      _ -> :error
    end
  end

  defp cast_integer(integer, byte_count) when is_integer(integer) do
    max_integer = byte_count_to_max_integer(byte_count)

    case integer do
      in_range when 0 <= in_range and in_range <= max_integer ->
        {:ok,
         %__MODULE__{byte_count: byte_count, bytes: <<integer::big-integer-size(byte_count)-unit(@bits_per_byte)>>}}

      _ ->
        :error
    end
  end

  defimpl String.Chars do
    def to_string(hash) do
      @for.to_string(hash)
    end
  end

  defimpl Poison.Encoder do
    def encode(hash, options) do
      hash
      |> to_string()
      |> BitString.encode(options)
    end
  end

  defimpl Jason.Encoder do
    alias Jason.Encode

    def encode(hash, opts) do
      hash
      |> to_string()
      |> Encode.string(opts)
    end
  end
end
