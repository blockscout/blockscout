defmodule Explorer.Chain.Hash.Address do
  @moduledoc """
  The address (40 (hex) characters / 160 bits / 20 bytes) is derived from the public key (128 (hex) characters /
  512 bits / 64 bytes) which is derived from the private key (64 (hex) characters / 256 bits / 32 bytes).

  The address is actually the last 40 characters of the keccak-256 hash of the public key with `0x` appended.
  """

  alias Explorer.Chain.Hash

  @behaviour Ecto.Type
  @behaviour Hash

  @byte_count 20
  @hexadecimal_digit_count Hash.hexadecimal_digits_per_byte() * @byte_count

  @typedoc """
  A #{@byte_count}-byte hash of the address public key.
  """
  @type t :: %Hash{byte_count: unquote(@byte_count), bytes: <<_::unquote(@byte_count * Hash.bits_per_byte())>>}

  @doc """
  Casts `term` to `t:t/0`.

  If the `term` is already in `t:t/0`, then it is returned

      iex> Explorer.Chain.Hash.Address.cast(
      ...>   %Explorer.Chain.Hash{
      ...>     byte_count: 20,
      ...>     bytes: <<0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed :: big-integer-size(20)-unit(8)>>
      ...>   }
      ...> )
      {
        :ok,
        %Explorer.Chain.Hash{
          byte_count: 20,
          bytes: <<0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed :: big-integer-size(20)-unit(8)>>
        }
      }

  If the `term` is an `non_neg_integer`, then it is converted to `t:t/0`

      iex> Explorer.Chain.Hash.Address.cast(0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed)
      {
        :ok,
        %Explorer.Chain.Hash{
          byte_count: 20,
          bytes: <<0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed :: big-integer-size(20)-unit(8)>>
        }
      }

  If the `non_neg_integer` is too large, then `:error` is returned.

      iex> Explorer.Chain.Hash.Address.cast(0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b)
      :error

  If the `term` is a `String.t` that starts with `0x`, then is converted to an integer and then to `t:t/0`.

      iex> Explorer.Chain.Hash.Address.cast("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")
      {
        :ok,
        %Explorer.Chain.Hash{
          byte_count: 20,
          bytes: <<0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed :: big-integer-size(20)-unit(8)>>
        }
      }

  While `non_neg_integers` don't have to be the correct width (because zero padding it difficult with numbers),
  `String.t` format must always have #{@hexadecimal_digit_count} digits after the `0x` base prefix.

      iex> Explorer.Chain.Hash.Address.cast("0x0")
      :error

  """
  @impl Ecto.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(term) do
    Hash.cast(__MODULE__, term)
  end

  @doc """
  Dumps the binary hash to `:binary` (`bytea`) format used in database.

  If the field from the struct is `t:t/0`, then it succeeds

      iex> Explorer.Chain.Hash.Address.dump(
      ...>   %Explorer.Chain.Hash{
      ...>     byte_count: 20,
      ...>     bytes: <<0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed :: big-integer-size(20)-unit(8)>>
      ...>   }
      ...> )
      {:ok, <<0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed :: big-integer-size(20)-unit(8)>>}

  If the field from the struct is an incorrect format such as `t:Explorer.Chain.Hash.t/0`, `:error` is returned

      iex> Explorer.Chain.Hash.Address.dump(
      ...>   %Explorer.Chain.Hash{
      ...>     byte_count: 32,
      ...>     bytes: <<0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b ::
      ...>              big-integer-size(32)-unit(8)>>
      ...>   }
      ...> )
      :error

  """
  @impl Ecto.Type
  @spec dump(term()) :: {:ok, binary} | :error
  def dump(term) do
    Hash.dump(__MODULE__, term)
  end

  @doc """
  Loads the binary hash from the database.

  If the binary hash is the correct format, it is returned.

      iex> Explorer.Chain.Hash.Address.load(
      ...>   <<0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed :: big-integer-size(20)-unit(8)>>
      ...> )
      {
        :ok,
        %Explorer.Chain.Hash{
          byte_count: 20,
          bytes: <<0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed :: big-integer-size(20)-unit(8)>>
        }
      }

  If the binary hash is an incorrect format, such as if an `Explorer.Chain.Hash` field is loaded, `:error` is returned.

      iex> Explorer.Chain.Hash.Address.load(
      ...>   <<0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b :: big-integer-size(32)-unit(8)>>
      ...> )
      :error

  """
  @impl Ecto.Type
  @spec load(term()) :: {:ok, t} | :error
  def load(term) do
    Hash.load(__MODULE__, term)
  end

  @doc """
  The underlying database type: `binary`.  `binary` is used because no Postgres integer type is 20 bytes long.
  """
  @impl Ecto.Type
  @spec type() :: :binary
  def type, do: :binary

  @impl Hash
  def byte_count, do: @byte_count
end
