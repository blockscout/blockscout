defmodule Indexer.Bech32 do
  @moduledoc """
  This is an implementation of BIP-0173

  Bech32 address format for native v0-16 witness outputs.

  See https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki for details
  """
  @gen {0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3}

  use Bitwise

  char_table = [
                 {0,  ~c(qpzry9x8)},
                 {8,  ~c(gf2tvdw0)},
                 {16, ~c(s3jn54kh)},
                 {24, ~c(ce6mua7l)},
               ] |> Enum.map(fn {x, chars} ->
    Enum.zip(chars, 0..(length(chars) - 1)) |> Enum.map(fn {char, val} ->
      {char, val + x}
    end)
  end) |> Enum.reduce([], &++/2)
               |> Enum.sort() |> MapSet.new()

  # Generate a lookup function
  for {char, val} <- char_table do
    defp char_to_value(unquote(char)), do: unquote(val)
    # Uppercase too
    if char  >= ?a and char <= ?z do
      char = char - ?a + ?A
      defp char_to_value(unquote(char)), do: unquote(val)
    end
  end

  defp char_to_value(_char) do
    nil
  end

  # Generate a lookup function
  for {char, val} <- char_table do
    defp value_to_char(unquote(val)), do: unquote(char)
  end

  defp value_to_char(_char) do
    nil
  end

  defp poly_mod(values) when is_list(values) do
    values |> Enum.reduce(1, fn v, chk ->
      b = (chk >>> 25)
      chk = bxor(((chk &&& 0x1ffffff) <<< 5), v)
      0..4 |> Enum.reduce(chk, fn i, chk ->
        bxor(chk, (if ((b >>> i) &&& 1) !== 0, do: @gen |> elem(i), else: 0))
      end)
    end)
  end

  defp hrp_expand(s) when is_binary(s) do
    chars = String.to_charlist(s)
    (for c <- chars, do: c >>> 5) ++ [0] ++ (for c <- chars, do: c &&& 31)
  end

  defp verify_checksum(hrp, data_string) when is_binary(hrp) and is_binary(data_string) do
    data = data_string |> String.to_charlist() |> Enum.map(&char_to_value/1)
    if data |> Enum.all?(&(&1 !== nil)) do
      if poly_mod(hrp_expand(hrp) ++ data) === 1 do
        :ok
      else
        {:error, :checksum_failed}
      end
    else
      {:error, :invalid_char}
    end
  end

  defp split_hrp_and_data_string(addr) do
    # Reversing is done here in case '1' is in the human readable part (hrp)
    # so we want to split on the last occurrence
    case String.split(addr |> String.reverse(), "1", parts: 2) do
      [data_string, hrp] ->
        {:ok, hrp |> String.reverse(), data_string |> String.reverse()}
      _ -> {:error, :not_bech32}
    end
  end

  @doc ~S"""
    Verify the checksum of the address report any errors. Note that this doesn't perform exhaustive validation
    of the address. If you need to make sure the address is well formed please use `decode/1` or `decode/2`
    instead.

    Returns `:ok` or an `{:error, reason}` tuple.

    ## Example
      iex> Bech32.verify("ckb1qyqdmeuqrsrnm7e5vnrmruzmsp4m9wacf6vsxasryq")
      :ok
  """
  @spec verify(String.t()) :: :ok | {:error, :checksum_failed | :invalid_char | :not_bech32}
  def verify(addr) when is_binary(addr) do
    case split_hrp_and_data_string(addr) do
      {:ok, hrp, data_string} -> verify_checksum(hrp, data_string)
      {:error, :not_bech32}   -> {:error, :not_bech32}
    end
  end

  @doc ~S"""
    Verify the checksum of the address report success or failure. Note that this doesn't perform exhaustive validation
    of the address. If you need to make sure the address is well formed please use `decode/1` or `decode/2`
    instead.

    Returns `true` or `false`.

    ## Example
      iex> Bech32.verify_predicate("ckb1qyqdmeuqrsrnm7e5vnrmruzmsp4m9wacf6vsxasryq")
      true
  """
  @spec verify_predicate(String.t()) :: boolean
  def verify_predicate(addr) when is_binary(addr) do
    case verify(addr) do
      :ok -> true
      _ -> false
    end
  end

  @doc ~S"""
    Get the human readable part of the address. Very little validation is done here please use `decode/1` or `decode/2`
    if you need to validate the address.

    Returns `{:ok, hrp :: String.t()}` or an `{:error, reason}` tuple.

    ## Example
      iex> Bech32.get_hrp("ckb1qyqdmeuqrsrnm7e5vnrmruzmsp4m9wacf6vsxasryq")
      {:ok, "ckb"}

  """
  @spec get_hrp(addr :: String.t()) :: {:ok, hrp :: String.t()} | {:error, :not_bech32}
  def get_hrp(addr) when is_binary(addr) do
    case split_hrp_and_data_string(addr) do
      {:ok, hrp, _data_string} -> {:ok, hrp}
      {:error, :not_bech32} -> {:error, :not_bech32}
    end
  end

  @doc ~S"""
    Create a checksum from the human readable part plus the data part.

    Returns a binary that represents the checksum.

    ## Example
      iex> Bech32.create_checksum("ckb", <<1, 0, 221, 231, 128, 28, 7, 61, 251, 52, 100, 199, 177, 240, 91, 128, 107, 178, 187, 184, 78, 153>>)
      <<4, 5, 2, 7, 25, 10>>
  """
  @spec create_checksum(String.t(), binary) :: binary
  def create_checksum(hrp, data) when is_binary(hrp) and is_binary(data) do
    data = :erlang.binary_to_list(data)
    values = hrp_expand(hrp) ++ data
    pmod = bxor(poly_mod(values ++ [0,0,0,0,0,0]), 1)
    (for i <- 0..5, do: (pmod >>> 5 * (5 - i)) &&& 31) |> :erlang.list_to_binary()
  end

  @doc ~S"""
    Encode a bech32 address from the hrp and data directly (data is a raw binary with no pre-processing).

    Returns a bech32 address as a string.

    ## Example
      iex> Bech32.encode("ckb", <<1, 0, 221, 231, 128, 28, 7, 61, 251, 52, 100, 199, 177, 240, 91, 128, 107, 178, 187, 184, 78, 153>>)
      "ckb1qyqdmeuqrsrnm7e5vnrmruzmsp4m9wacf6vsxasryq"
  """
  @spec encode(String.t(), binary) :: String.t()
  def encode(hrp, data) when is_binary(hrp) and is_binary(data) do
    encode_from_5bit(hrp, convert_bits(data))
  end

  @doc ~S"""
    Encode address from 5 bit encoded values in each byte. In other words bytes should have a value between `0` and `31`.

    Returns a bech32 address as a string.

    ## Example
      iex> Bech32.encode_from_5bit("ckb", Bech32.convert_bits(<<1, 0, 221, 231, 128, 28, 7, 61, 251, 52, 100, 199, 177, 240, 91, 128, 107, 178, 187, 184, 78, 153>>))
      "ckb1qyqdmeuqrsrnm7e5vnrmruzmsp4m9wacf6vsxasryq"
  """
  @spec encode_from_5bit(String.t(), binary) :: String.t()
  def encode_from_5bit(hrp, data) when is_binary(hrp) and is_binary(data) do
    hrp <> "1" <> :erlang.list_to_binary(for << d :: 8 <- data <> create_checksum(hrp, data) >>, do: value_to_char(d))
  end

  @doc ~S"""
    Convert raw binary to 5 bit per byte encoded byte string.

    Returns a binary that uses 5 bits per byte.

    ## Example
      iex> Bech32.convert_bits(<<1, 0, 221, 231, 128, 28, 7, 61, 251, 52, 100, 199, 177, 240, 91, 128, 107, 178, 187, 184, 78, 153>>)
      <<0, 4, 0, 13, 27, 25, 28, 0, 3, 16, 3, 19, 27, 30, 25, 20, 12, 19, 3, 27, 3, 28, 2, 27, 16, 1, 21, 27, 5, 14, 29, 24, 9, 26, 12, 16>>
  """
  @spec convert_bits(binary, pos_integer, pos_integer, boolean) :: binary
  def convert_bits(data, frombits \\ 8, tobits \\ 5, pad \\ true)
  def convert_bits(data, frombits, tobits, pad)
      when is_binary(data) and is_integer(frombits) and is_integer(tobits) and is_boolean(pad) and
           (frombits >= tobits) and (frombits > 0) and (tobits > 0)
    do
    num_data_bits = bit_size(data)
    num_tail_bits = rem(num_data_bits, tobits)
    data = if pad do
      missing_bits = 8 - num_tail_bits
      << data :: bitstring,  0 :: size(missing_bits)>>
    else
      data
    end
    :erlang.list_to_binary(for << x :: size(tobits) <- data >>, do: x)
  end
  def convert_bits(data, frombits, tobits, pad)
      when is_binary(data) and is_integer(frombits) and is_integer(tobits) and is_boolean(pad) and
           (frombits <= tobits) and (frombits > 0) and (tobits > 0)
    do
    data = data |> :erlang.binary_to_list() |> Enum.reverse() |> Enum.reduce("", fn v, acc ->
      << v :: size(frombits), acc :: bitstring >>
    end)
    data = if pad do
      leftover_bits = bit_size(data) |> rem(tobits)
      padding_bits = tobits - leftover_bits
      << data :: bitstring, 0 :: size(padding_bits) >>
    else
      data
    end
    (for << c :: size(tobits) <- data >>, do: c) |> :erlang.list_to_binary()
  end

  @doc ~S"""
    Encode a bech32 segwit address.

    Returns a bech32 address as a string.

    ## Example
      iex> Bech32.segwit_encode("bc", 0, <<167, 63, 70, 122, 93, 154, 138, 11, 103, 41, 15, 251, 14, 239, 131, 2, 30, 176, 138, 212>>)
      "bc1q5ul5v7jan29qkeefplasamurqg0tpzk5ljjhm6"
  """
  @spec segwit_encode(String.t(), non_neg_integer, binary) :: String.t()
  def segwit_encode(hrp, witver, witprog)
      when is_binary(hrp) and is_integer(witver) and (witver >= 0 or witver < 16) and is_binary(witprog) do
    encode_from_5bit(hrp, << witver :: 8, (convert_bits(witprog, 8, 5, false)) :: binary >>)
  end

  @doc ~S"""
    Decode a bech32 address. You can also pass the `:ignore_length` keyword into the opts if you want to allow
    more than 90 chars for currencies like Nervos CKB.

    Returns `{:ok, hrp :: String.t(), data :: binary}` or an `{:error, reason}` tuple. Note that we return 8 bits per
    byte here not 5 bits per byte.

    ## Example
      iex> Bech32.decode("ckb1qyq036wytncnfv0ekfjqrch7s5hzr4hkjl4qs54f7e")
      {:ok, "ckb", <<1, 0, 248, 233, 196, 92, 241, 52, 177, 249, 178, 100, 1, 226, 254, 133, 46, 33, 214, 246, 151, 234>>}

  """
  @spec decode(String.t(), keyword) :: {:ok, hrp :: String.t(), data :: binary} |
                                       {:error,
                                         :no_separator | :no_hrp | :checksum_too_short | :too_long | :not_in_charset |
                                                                                                     :checksum_failed | :invalid_char | :mixed_case_char
                                       }
  def decode(addr, opts \\ []) when is_binary(addr) do
    unless Enum.any?(:erlang.binary_to_list(addr), fn c -> c < ?! or c > ?~ end) do
      unless (String.downcase(addr) !== addr) and (String.upcase(addr) !== addr) do
        addr = String.downcase(addr)
        data_part = ~r/.+(1[qpzry9x8gf2tvdw0s3jn54khce6mua7l]+)$/ |> Regex.run(addr)
        case ~r/.+(1.+)$/ |> Regex.run(addr, return: :index) do
          nil -> {:error, :no_separator}
          [_, {last_one_pos, _tail_size_including_one}] ->
            cond do
              last_one_pos === 0 ->
                {:error, :no_hrp}
              (last_one_pos + 7) > byte_size(addr) ->
                {:error, :checksum_too_short}
                byte_size(addr) > 90 and Keyword.get(opts, :ignore_length, false)
                {:error, :too_long}
              data_part === nil ->
                {:error, :not_in_charset}
              true ->
                << hrp :: binary-size(last_one_pos), "1", data_with_checksum :: binary >> = addr

                case verify_checksum(hrp, data_with_checksum) do
                  :ok ->
                    checksum_bits = 6 * 8
                    data_bits = bit_size(data_with_checksum) - checksum_bits
                    << data :: bitstring-size(data_bits), _checksum :: size(checksum_bits) >> = data_with_checksum
                    data = data
                           |> :erlang.binary_to_list()
                           |> Enum.map(&char_to_value/1)
                           |> Enum.reverse()
                           |> Enum.reduce(
                                "",
                                fn v, acc ->
                                  << v :: 5, acc :: bitstring >>
                                end)
                    data_bitlen = bit_size(data)
                    data_bytes = div(data_bitlen, 8)
                    data = case rem(data_bitlen, 8) do
                      0 -> data
                      n when n < 5 ->
                        data_bitlen = data_bytes * 8
                        << data :: bitstring-size(data_bitlen), _ :: bitstring >> = data
                        data
                      n ->
                        missing_bits = 8 - n
                        << data :: bitstring, 0 :: size(missing_bits) >>
                    end
                    {:ok, hrp, data}
                  {:error, reason} -> {:error, reason}
                end
            end
        end
      else
        {:error, :mixed_case_char}
      end
    else
      {:error, :invalid_char}
    end
  end

  @doc ~S"""
    Decode a segwit bech32 address.

    Returns `{:ok, witver :: non_neg_integer , data :: binary}` or an `{:error, reason}` tuple. Note that we return 8 bits per
    byte here not 5 bits per byte.

    ## Example
      iex> Bech32.segwit_decode("bc", "bc1q5ul5v7jan29qkeefplasamurqg0tpzk5ljjhm6")
      {:ok, 0, <<167, 63, 70, 122, 93, 154, 138, 11, 103, 41, 15, 251, 14, 239, 131, 2, 30, 176, 138, 212>>}

  """
  @spec segwit_decode(hrp :: String.t(), addr :: String.t()) :: {:ok, witver :: non_neg_integer, data :: binary} |
                                                                {:error,
                                                                  :invalid_size | :invalid_witness_version | :wrong_hrp | :no_seperator | :no_hrp | :checksum_too_short |
                                                                                                                                                    :too_long | :not_in_charset | :checksum_failed | :invalid_char | :mixed_case_char
                                                                }
  def segwit_decode(hrp, addr) when is_binary(hrp) and is_binary(addr) do
    case decode(addr) do
      {:ok, ^hrp, data_8bit} ->
        << witver :: 8, data :: binary >> =  convert_bits(data_8bit, 8, 5, true)
        decoded = convert_bits(data, 5, 8, false)
        decoded_size = byte_size(decoded)
        with {_, false} <- {:invalid_size, decoded_size < 2 or decoded_size > 40},
             {_, false} <- {:invalid_witness_version, witver > 16},
             {_, false} <- {:invalid_size, witver === 0 and decoded_size !== 20 and decoded_size !== 32}
          do
          {:ok, witver, decoded}
        else
          {reason, _} -> {:error, reason}
        end
      {:ok, _other_hrp, _data} ->
        {:error, :wrong_hrp}
      {:error, reason} -> {:error, reason}
    end
  end
end