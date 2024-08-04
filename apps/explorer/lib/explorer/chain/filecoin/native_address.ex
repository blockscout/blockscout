defmodule Explorer.Chain.Filecoin.NativeAddress do
  @moduledoc """
  Handles Filecoin addresses by parsing, validating, and converting them to and
  from their binary representations.

  Addresses are encoded to binary according to the [Filecoin Address
  spec](https://spec.filecoin.io/appendix/address/#section-appendix.address.validatechecksum).
  Details about f4 addresses are provided in
  [FIP-0048](https://github.com/filecoin-project/FIPs/blob/master/FIPS/fip-0048.md).

  Internally, addresses are stored as a binary with the following structure:

  ```
  |--------------------|---------|
  | protocol indicator | payload |
  |--------------------|---------|
  |       1 byte       | n bytes |
  ```

  1. The first byte is the protocol indicator encoded as a LEB128 integer. The
     values are:
     - `0` for f0 addresses
     - `1` for f1 addresses
     - `2` for f2 addresses
     - `3` for f3 addresses
     - `actor_id` for f4 addresses (see FIP-0048)

  2. The remaining bytes are the payload.
  """

  import Explorer.Helper, only: [parse_integer: 1]

  alias Explorer.Chain.Hash
  alias Poison.Encoder.BitString
  alias Varint.LEB128

  use Ecto.Type

  defstruct ~w(protocol_indicator payload checksum)a

  @checksum_bytes_count 4

  @protocol_indicator_bytes_count 1
  @max_protocol_indicator 2 ** (@protocol_indicator_bytes_count * Hash.bits_per_byte()) - 1

  @min_address_string_length 3

  # Payload sizes:
  # f1 -- 65 bytes
  # f2 -- 32 bytes
  # f3 -- 48 bytes
  @protocol_indicator_to_payload_byte_count %{
    1 => 20,
    # todo: WTF? Should be 32. Docs are lying
    2 => 20,
    3 => 48
  }
  @standard_protocol_indicators Map.keys(@protocol_indicator_to_payload_byte_count)

  @type t :: %__MODULE__{
          protocol_indicator: non_neg_integer(),
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
      ...>     payload: <<193, 13>>,
      ...>     checksum: nil
      ...>   }
      ...> )
      {
        :ok,
        %Explorer.Chain.Filecoin.NativeAddress{
          protocol_indicator: 0,
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
          payload: <<193, 13>>,
          checksum: nil
        }
      }

      iex> Explorer.Chain.Filecoin.NativeAddress.cast("f01729")
      {
        :ok,
        %Explorer.Chain.Filecoin.NativeAddress{
          protocol_indicator: 1,
          payload: <<253, 29, 15, 77, 252, 215, 233, 154, 252, 185, 154, 131, 38, 183, 220, 69, 157, 50, 198, 40>>,
          checksum: <<148, 236, 248, 227>>
        }
      }

      iex> NativeAddress.cast("f410fabpafjfjgqkc3douo3yzfug5tq4bwfvuhsewxji")
      {
        :ok,
        %Explorer.Chain.Filecoin.NativeAddress{
          protocol_indicator: 10,
          payload: <<0, 94, 2, 164, 169, 52, 20, 45, 141, 212, 118, 241, 146, 208, 221, 156, 56, 27, 22, 180>>,
          checksum: <<60, 137, 107, 165>>
        }
      }
  """

  @impl Ecto.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(term) when is_binary(term) do
    network = network_prefix()

    with true <- String.length(term) >= @min_address_string_length,
         ^network <> protocol_indicator_and_payload <- term do
      cast_protocol_indicator_and_payload(protocol_indicator_and_payload)
    else
      _ ->
        :error
    end
  end

  defp cast_protocol_indicator_and_payload("0" <> id_string) do
    id_string
    |> parse_integer()
    |> case do
      id when is_integer(id) and id >= 0 ->
        payload = LEB128.encode(id)

        {:ok,
         %__MODULE__{
           protocol_indicator: 0,
           payload: payload,
           checksum: nil
         }}

      _ ->
        :error
    end
  end

  defp cast_protocol_indicator_and_payload("4" <> rest) do
    with [actor_id_string, base32_digits] <- String.split(rest, "f", parts: 2),
         actor_id when is_integer(actor_id) <- parse_integer(actor_id_string),
         {:ok, {payload, checksum}} <- cast_base32_digits(base32_digits) do
      {:ok,
       %__MODULE__{
         protocol_indicator: actor_id,
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
         protocol_indicator when protocol_indicator in @standard_protocol_indicators <-
           protocol_indicator_string |> parse_integer(),
         {:ok, byte_count} <-
           Map.fetch(
             @protocol_indicator_to_payload_byte_count,
             protocol_indicator
           ),
         {:ok, {payload, checksum}} <- cast_base32_digits(base32_digits, byte_count) do
      {:ok,
       %__MODULE__{
         protocol_indicator: protocol_indicator,
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
         >> = bytes do
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
  def dump(%__MODULE__{protocol_indicator: protocol_indicator, payload: payload})
      when is_integer(protocol_indicator) and
             is_binary(payload) and
             protocol_indicator >= 0 and
             protocol_indicator <= @max_protocol_indicator do
    protocol_indicator_bytes = LEB128.encode(protocol_indicator)
    {:ok, <<protocol_indicator_bytes::binary, payload::binary>>}
  end

  def dump(_), do: :error

  @doc """
  Loads the address from `:binary` representation used in database.
  """
  @impl Ecto.Type
  @spec load(binary()) :: {:ok, t()} | :error
  def load(
        <<
          protocol_indicator_byte::unquote(Hash.bits_per_byte()),
          payload::binary
        >> = bytes
      ) do
    <<protocol_indicator_byte>>
    |> LEB128.decode()
    |> case do
      {protocol_indicator, <<>>} ->
        checksum = to_checksum(bytes)

        {:ok,
         %__MODULE__{
           protocol_indicator: protocol_indicator,
           payload: payload,
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
      ...>     payload: <<193, 13>>,
      ...>     checksum: nil
      ...>   }
      ...> )
      "f01729"

      iex> Explorer.Chain.Filecoin.NativeAddress.to_string(
      ...>   %Explorer.Chain.Filecoin.NativeAddress{
      ...>     protocol_indicator: 10,
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

        indicator ->
          "4" <> Integer.to_string(indicator) <> "f"
      end

    network_prefix() <> protocol_indicator_part <> payload_with_checksum
  end

  defp to_checksum(bytes) do
    :blake2b
    |> :crypto.hash(bytes)
    |> :binary.part(0, @checksum_bytes_count)
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
