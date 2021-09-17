defmodule Explorer.Chain.Hash.Address do
  @moduledoc """
  The address (40 (hex) characters / 160 bits / 20 bytes) is derived from the public key (128 (hex) characters /
  512 bits / 64 bytes) which is derived from the private key (64 (hex) characters / 256 bits / 32 bytes).

  The address is actually the last 40 characters of the keccak-256 hash of the public key with `0x` appended.
  """

  alias Explorer.Chain.Hash

  use Ecto.Type
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

  @doc """
  Validates a hexadecimal encoded string to see if it conforms to an address.

  ## Error Descriptions

  * `:invalid_characters` - String used non-hexadecimal characters
  * `:invalid_checksum` - Mixed-case string didn't pass [EIP-55 checksum](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-55.md)
  * `:invalid_length` - Addresses are expected to be 40 hex characters long

  ## Example

      iex> Explorer.Chain.Hash.Address.validate("0xc1912fEE45d61C87Cc5EA59DaE31190FFFFf232d")
      {:ok, "0xc1912fEE45d61C87Cc5EA59DaE31190FFFFf232d"}

      iex> Explorer.Chain.Hash.Address.validate("0xc1912fEE45d61C87Cc5EA59DaE31190FFFFf232H")
      {:error, :invalid_characters}
  """
  @spec validate(String.t()) :: {:ok, String.t()} | {:error, :invalid_length | :invalid_characters | :invalid_checksum}
  def validate("0x" <> hash) do
    with {:length, true} <- {:length, String.length(hash) == 40},
         {:hex, true} <- {:hex, is_hex?(hash)},
         {:mixed_case, true} <- {:mixed_case, is_mixed_case?(hash)},
         {:checksummed, true} <- {:checksummed, is_checksummed?(hash)} do
      {:ok, "0x" <> hash}
    else
      {:length, false} ->
        {:error, :invalid_length}

      {:hex, false} ->
        {:error, :invalid_characters}

      {:mixed_case, false} ->
        {:ok, "0x" <> hash}

      {:checksummed, false} ->
        {:error, :invalid_checksum}
    end
  end

  @spec is_hex?(String.t()) :: boolean()
  defp is_hex?(hash) do
    case Regex.run(~r|[0-9a-f]{40}|i, hash) do
      nil -> false
      [_] -> true
    end
  end

  @spec is_mixed_case?(String.t()) :: boolean()
  defp is_mixed_case?(hash) do
    upper_check = ~r|[0-9A-F]{40}|
    lower_check = ~r|[0-9a-f]{40}|

    with nil <- Regex.run(upper_check, hash),
         nil <- Regex.run(lower_check, hash) do
      true
    else
      _ -> false
    end
  end

  @spec is_checksummed?(String.t()) :: boolean()
  defp is_checksummed?(original_hash) do
    lowercase_hash = String.downcase(original_hash)
    sha3_hash = ExKeccak.hash_256(lowercase_hash)

    do_checksum_check(sha3_hash, original_hash)
  end

  @spec do_checksum_check(binary(), String.t()) :: boolean()
  defp do_checksum_check(_, ""), do: true

  defp do_checksum_check(sha3_hash, address_hash) do
    <<checksum_digit::integer-size(4), remaining_sha3_hash::bits>> = sha3_hash
    <<current_char::binary-size(1), remaining_address_hash::binary>> = address_hash

    if is_proper_case?(checksum_digit, current_char) do
      do_checksum_check(remaining_sha3_hash, remaining_address_hash)
    else
      false
    end
  end

  @spec is_proper_case?(integer, String.t()) :: boolean()
  defp is_proper_case?(checksum_digit, character) do
    case_map = %{
      "0" => :both,
      "1" => :both,
      "2" => :both,
      "3" => :both,
      "4" => :both,
      "5" => :both,
      "6" => :both,
      "7" => :both,
      "8" => :both,
      "9" => :both,
      "a" => :lower,
      "b" => :lower,
      "c" => :lower,
      "d" => :lower,
      "e" => :lower,
      "f" => :lower,
      "A" => :upper,
      "B" => :upper,
      "C" => :upper,
      "D" => :upper,
      "E" => :upper,
      "F" => :upper
    }

    character_case = Map.get(case_map, character)

    # Digits with checksum digit greater than 7 should be uppercase
    if checksum_digit > 7 do
      character_case in ~w(both upper)a
    else
      character_case in ~w(both lower)a
    end
  end
end
