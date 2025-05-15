defmodule Explorer.Chain.Filecoin.NativeAddress do
  @moduledoc """
  Handles Filecoin addresses by parsing, validating, and converting them to and
  from their binary representations.

  Addresses are encoded to binary according to the [Filecoin Address
  spec](https://spec.filecoin.io/appendix/address/#section-appendix.address.validatechecksum).
  Details about f4 addresses are provided in
  [FIP-0048](https://github.com/filecoin-project/FIPs/blob/master/FIPS/fip-0048.md).

  Internally, f0/f1/f2/f3 addresses are stored as a binary with the following structure:

  |--------------------|---------|
  | protocol indicator | payload |
  |--------------------|---------|
  |       1 byte       | n bytes |
  |--------------------|---------|

  1. The first byte is the protocol indicator. The values are:
     - `0` for f0 addresses
     - `1` for f1 addresses
     - `2` for f2 addresses
     - `3` for f3 addresses

  2. The remaining bytes are the payload.

  f4 addresses are stored as a binary with the following structure:

  |--------------------|----------|---------|
  | protocol indicator | actor id | payload |
  |--------------------|----------|---------|
  |       1 byte       |  1 byte  | n bytes |
  |--------------------|----------|---------|

  1. The first byte is the protocol indicator. The value is `4`.
  2. The second byte is the actor id.
  3. The remaining bytes are the payload.
  """

  alias Explorer.Chain.Hash
  alias Poison.Encoder.BitString
  alias Varint.LEB128

  use Ecto.Type

  defstruct ~w(protocol_indicator actor_id payload checksum)a

  @checksum_bytes_count 4

  @protocol_indicator_bytes_count 1
  @max_actor_id 2 ** (@protocol_indicator_bytes_count * Hash.bits_per_byte()) - 1
  @ethereum_actor_id 10

  @min_address_string_length 3

  # Payload sizes:
  # f1 -- 20 bytes
  # f2 -- 20 bytes
  # f3 -- 48 bytes
  @protocol_indicator_to_payload_byte_count %{
    1 => 20,
    # For some reason, specs tell that payload for f2 is a SHA256 hash, which is
    # 32 bytes long. However, in practice, it is 20 bytes long...
    #
    # https://spec.filecoin.io/appendix/address/#section-appendix.address.protocol-2-actor
    2 => 20,
    3 => 48
  }
  @standard_protocol_indicators Map.keys(@protocol_indicator_to_payload_byte_count)

  @id_address_eth_prefix <<255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>

  @type t :: %__MODULE__{
          protocol_indicator: non_neg_integer(),
          actor_id: non_neg_integer() | nil,
          payload: binary(),
          checksum: binary() | nil
        }

  @impl Ecto.Type
  @spec type() :: :binary
  def type, do: :binary

  defp network_prefix do
    Atom.to_string(Application.get_env(:explorer, __MODULE__)[:network_prefix])
  end

  @doc """
  Casts `term` to `t:t/0`.

  If the term is already in `t:t/0`, then it is returned

      iex> Explorer.Chain.Filecoin.NativeAddress.cast(
      ...>   %Explorer.Chain.Filecoin.NativeAddress{
      ...>     protocol_indicator: 0,
      ...>     actor_id: nil,
      ...>     payload: <<193, 13>>,
      ...>     checksum: nil
      ...>   }
      ...> )
      {
        :ok,
        %Explorer.Chain.Filecoin.NativeAddress{
          protocol_indicator: 0,
          actor_id: nil,
          payload: <<193, 13>>,
          checksum: nil
        }
      }

  If the term is a binary, then it is parsed to `t:t/0`

      iex> Explorer.Chain.Filecoin.NativeAddress.cast("f01729")
      {
        :ok,
        %Explorer.Chain.Filecoin.NativeAddress{
          protocol_indicator: 0,
          actor_id: nil,
          payload: <<193, 13>>,
          checksum: nil
        }
      }

      iex> Explorer.Chain.Filecoin.NativeAddress.cast("f01729")
      {
        :ok,
        %Explorer.Chain.Filecoin.NativeAddress{
          protocol_indicator: 0,
          actor_id: nil,
          payload: <<193, 13>>,
          checksum: nil
        }
      }

      iex> NativeAddress.cast("f410fabpafjfjgqkc3douo3yzfug5tq4bwfvuhsewxji")
      {
        :ok,
        %Explorer.Chain.Filecoin.NativeAddress{
          protocol_indicator: 4,
          actor_id: 10,
          payload: <<0, 94, 2, 164, 169, 52, 20, 45, 141, 212, 118, 241, 146, 208, 221, 156, 56, 27, 22, 180>>,
          checksum: <<60, 137, 107, 165>>
        }
      }

  If the term is a `Hash` struct, then it is converted to `t:t/0`

      iex> Explorer.Chain.Filecoin.NativeAddress.cast(
      ...>   %Explorer.Chain.Hash{
      ...>     byte_count: 20,
      ...>     bytes: <<0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed :: big-integer-size(20)-unit(8)>>
      ...>   }
      ...> )
      {
        :ok,
        %Explorer.Chain.Filecoin.NativeAddress{
          protocol_indicator: 4,
          actor_id: 10,
          payload: <<90, 174, 182, 5, 63, 62, 148, 201, 185, 160, 159, 51, 102, 148, 53, 231, 239, 27, 234, 237>>,
          checksum: <<238, 18, 207, 48>>
        }
      }

      iex> Explorer.Chain.Filecoin.NativeAddress.cast(
      ...>   %Explorer.Chain.Hash{
      ...>     byte_count: 20,
      ...>     bytes: <<0xff00000000000000000000000000000000302F7B :: big-integer-size(20)-unit(8)>>
      ...>   }
      ...> )
      {
        :ok,
        %Explorer.Chain.Filecoin.NativeAddress{
          protocol_indicator: 0,
          actor_id: nil,
          payload: <<251, 222, 192, 1>>,
          checksum: nil
        }
      }
  """
  @impl Ecto.Type
  @spec cast(t() | String.t() | Hash.Address.t()) :: {:ok, t()} | :error
  def cast(%__MODULE__{} = address), do: {:ok, address}

  def cast(address_string) when is_binary(address_string) do
    network = network_prefix()

    with true <- String.length(address_string) >= @min_address_string_length,
         ^network <> protocol_indicator_and_payload <- address_string,
         {:ok, address} <- cast_protocol_indicator_and_payload(protocol_indicator_and_payload),
         :ok <- verify_checksum(address) do
      {:ok, address}
    else
      _ ->
        :error
    end
  end

  def cast(%Hash{bytes: <<@id_address_eth_prefix::binary, rest::binary>>}) do
    payload =
      rest
      |> :binary.decode_unsigned()
      |> LEB128.encode()

    {
      :ok,
      %__MODULE__{
        protocol_indicator: 0,
        actor_id: nil,
        payload: payload,
        checksum: nil
      }
    }
  end

  def cast(%Hash{bytes: payload}) do
    dumped = <<4, @ethereum_actor_id, payload::binary>>
    checksum = to_checksum(dumped)

    {
      :ok,
      %__MODULE__{
        protocol_indicator: 4,
        actor_id: @ethereum_actor_id,
        payload: payload,
        checksum: checksum
      }
    }
  end

  defp cast_protocol_indicator_and_payload("0" <> id_string) do
    id_string
    |> Integer.parse()
    |> case do
      {id, ""} when is_integer(id) and id >= 0 ->
        payload = LEB128.encode(id)

        {:ok,
         %__MODULE__{
           protocol_indicator: 0,
           actor_id: nil,
           payload: payload,
           checksum: nil
         }}

      _ ->
        :error
    end
  end

  defp cast_protocol_indicator_and_payload("4" <> rest) do
    with [actor_id_string, base32_digits] <- String.split(rest, "f", parts: 2),
         {actor_id, ""} when is_integer(actor_id) <- Integer.parse(actor_id_string),
         {:ok, {payload, checksum}} <- cast_base32_digits(base32_digits) do
      {:ok,
       %__MODULE__{
         protocol_indicator: 4,
         actor_id: actor_id,
         payload: payload,
         checksum: checksum
       }}
    else
      _ -> :error
    end
  end

  defp cast_protocol_indicator_and_payload(protocol_indicator_and_payload) do
    with {protocol_indicator_string, base32_digits} <-
           String.split_at(
             protocol_indicator_and_payload,
             1
           ),
         {protocol_indicator, ""} when protocol_indicator in @standard_protocol_indicators <-
           Integer.parse(protocol_indicator_string),
         {:ok, byte_count} <-
           Map.fetch(
             @protocol_indicator_to_payload_byte_count,
             protocol_indicator
           ),
         {:ok, {payload, checksum}} <- cast_base32_digits(base32_digits, byte_count) do
      {:ok,
       %__MODULE__{
         protocol_indicator: protocol_indicator,
         actor_id: nil,
         payload: payload,
         checksum: checksum
       }}
    else
      _ -> :error
    end
  end

  defp cast_base32_digits(digits) do
    with {:ok, bytes} <- Base.decode32(digits, case: :lower, padding: false),
         <<
           payload::binary-size(byte_size(bytes) - @checksum_bytes_count),
           checksum::binary-size(@checksum_bytes_count)
         >> <- bytes do
      {:ok, {payload, checksum}}
    else
      _ -> :error
    end
  end

  defp cast_base32_digits(digits, expected_bytes_count) do
    with {:ok, {payload, checksum}} <- cast_base32_digits(digits),
         true <- byte_size(payload) == expected_bytes_count do
      {:ok, {payload, checksum}}
    else
      _ -> :error
    end
  end

  @doc """
  Dumps the address to `:binary` (`bytea`) representation format used in
  database.
  """
  @impl Ecto.Type
  @spec dump(t()) :: {:ok, binary()} | :error
  def dump(%__MODULE__{protocol_indicator: 4, actor_id: actor_id, payload: payload})
      when is_integer(actor_id) and
             is_binary(payload) and
             actor_id >= 0 and
             actor_id <= @max_actor_id do
    {:ok, <<4, actor_id, payload::binary>>}
  end

  def dump(%__MODULE__{protocol_indicator: protocol_indicator, payload: payload})
      when is_integer(protocol_indicator) and
             is_binary(payload) and
             protocol_indicator >= 0 and
             protocol_indicator <= @max_actor_id do
    {:ok, <<protocol_indicator, payload::binary>>}
  end

  def dump(_), do: :error

  @doc """
  Loads the address from `:binary` representation used in database.
  """
  @impl Ecto.Type
  @spec load(binary()) :: {:ok, t()} | :error
  def load(<<protocol_indicator, rest::binary>> = bytes) do
    case protocol_indicator do
      0 ->
        {:ok,
         %__MODULE__{
           protocol_indicator: 0,
           actor_id: nil,
           payload: rest,
           checksum: nil
         }}

      4 ->
        checksum = to_checksum(bytes)
        <<actor_id, payload::binary>> = rest

        {:ok,
         %__MODULE__{
           protocol_indicator: 4,
           actor_id: actor_id,
           payload: payload,
           checksum: checksum
         }}

      protocol_indicator when protocol_indicator in @standard_protocol_indicators ->
        checksum = to_checksum(bytes)

        {:ok,
         %__MODULE__{
           protocol_indicator: protocol_indicator,
           actor_id: nil,
           payload: rest,
           checksum: checksum
         }}

      _ ->
        :error
    end
  end

  def load(_), do: :error

  @doc """
  Converts the address to a string representation.

      iex> Explorer.Chain.Filecoin.NativeAddress.to_string(
      ...>   %Explorer.Chain.Filecoin.NativeAddress{
      ...>     protocol_indicator: 0,
      ...>     actor_id: nil,
      ...>     payload: <<193, 13>>,
      ...>     checksum: nil
      ...>   }
      ...> )
      "f01729"

      iex> Explorer.Chain.Filecoin.NativeAddress.to_string(
      ...>   %Explorer.Chain.Filecoin.NativeAddress{
      ...>     protocol_indicator: 4,
      ...>     actor_id: 10,
      ...>     payload: <<0, 94, 2, 164, 169, 52, 20, 45, 141, 212, 118, 241, 146, 208, 221, 156, 56, 27, 22, 180>>,
      ...>     checksum: <<60, 137, 107, 165>>
      ...>   }
      ...> )
      "f410fabpafjfjgqkc3douo3yzfug5tq4bwfvuhsewxji"
  """
  @spec to_string(t) :: String.t()
  def to_string(%__MODULE__{protocol_indicator: 0, payload: payload}) do
    {id, <<>>} = LEB128.decode(payload)
    network_prefix() <> "0" <> Integer.to_string(id)
  end

  @spec to_string(t) :: String.t()
  def to_string(%__MODULE__{
        protocol_indicator: protocol_indicator,
        payload: payload,
        actor_id: actor_id,
        checksum: checksum
      }) do
    payload_with_checksum =
      Base.encode32(
        payload <> checksum,
        case: :lower,
        padding: false
      )

    protocol_indicator_part =
      protocol_indicator
      |> case do
        indicator when indicator in @standard_protocol_indicators ->
          Integer.to_string(indicator)

        4 ->
          "4" <> Integer.to_string(actor_id) <> "f"
      end

    network_prefix() <> protocol_indicator_part <> payload_with_checksum
  end

  defp verify_checksum(%__MODULE__{protocol_indicator: 0, checksum: nil}), do: :ok

  defp verify_checksum(%__MODULE__{checksum: checksum} = address)
       when not is_nil(checksum) do
    with {:ok, bytes} <- dump(address),
         ^checksum <- to_checksum(bytes) do
      :ok
    else
      _ -> :error
    end
  end

  defp to_checksum(bytes),
    do: Blake2.hash2b(bytes, @checksum_bytes_count)

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
