defmodule Explorer.Celo.ContractEvents.Common do
  @moduledoc "Common functionality for import in Celo contract event structs"

  alias ABI.{FunctionSelector, TypeDecoder}
  alias Explorer.Chain.Hash.Address
  alias Explorer.Chain.{Data, Hash, Hash.Full}

  @doc "Decode a single point of event data of a given type from a given topic"
  def decode_event_topic(topic, type) do
    if FunctionSelector.is_dynamic?(type) do
      # dynamic types indexed as event topics will be encoded as a 32 bit keccak hash of the input value
      # as per solidity abi spec
      # https://docs.soliditylang.org/en/develop/abi-spec.html#indexed-event-encoding

      # quoting from ex_abi documentation:

      # The caller will almost certainly
      # need to know that they don't have an actual encoded value of that type
      # but rather they have a 32 bit hash of the value.

      decode_event_topic(topic, {:bytes, 32})
    else
      topic
      |> extract_hash()
      |> TypeDecoder.decode_raw([type])
      |> List.first()
      |> convert_type_to_elixir(type)
    end
  end

  @doc "Decode event data of given types from log data"
  def decode_event_data(%Data{bytes: bytes}, types), do: decode_event_data(bytes, types)

  def decode_event_data("0x" <> data, types) do
    data
    |> Base.decode16!(case: :lower)
    |> decode_event_data(types)
  end

  def decode_event_data(data, types) when is_binary(data) do
    data
    |> TypeDecoder.decode_raw(types)
    |> Enum.zip(types)
    |> Enum.map(fn {decoded, type} -> convert_type_to_elixir(decoded, type) end)
  end

  defp extract_hash(event_data), do: event_data |> String.trim_leading("0x") |> Base.decode16!(case: :lower)

  # list of bytes to 2d list of ints
  defp convert_type_to_elixir(decoded, {:array, {:bytes, _}}), do: decoded |> Enum.map(&:binary.bin_to_list(&1))
  defp convert_type_to_elixir(decoded, {:array, :bytes}), do: decoded |> Enum.map(&:binary.bin_to_list(&1))
  # bytes to list of ints
  defp convert_type_to_elixir(decoded, {:bytes, _size}), do: :binary.bin_to_list(decoded)
  defp convert_type_to_elixir(decoded, :bytes), do: :binary.bin_to_list(decoded)

  defp convert_type_to_elixir(decoded, :address) do
    {:ok, address} = Address.cast(decoded)
    address
  end

  # default - assume valid conversion
  defp convert_type_to_elixir(decoded, _type), do: decoded

  def extract_common_event_params(event) do
    # handle optional transaction hash
    common_properties =
      case Map.get(event, :__transaction_hash) do
        nil ->
          %{transaction_hash: nil}

        v ->
          {:ok, hsh} = Full.cast(v)
          %{transaction_hash: hsh}
      end

    {:ok, hsh} = Address.cast(event.__contract_address_hash)

    common_properties
    |> Map.put(:contract_address_hash, hsh)
    |> Map.put(:name, event.__name)
    |> Map.put(:topic, event.__topic)
    |> Map.put(:block_number, event.__block_number)
    |> Map.put(:log_index, event.__log_index)
  end

  @doc "Store address in postgres json format to make joins work with indices"
  def format_address_for_postgres_json(%Hash{} = address),
    do: address |> to_string() |> format_address_for_postgres_json()

  def format_address_for_postgres_json(nil), do: "\\x"
  def format_address_for_postgres_json("\\x" <> _rest = address), do: address
  def format_address_for_postgres_json("0x" <> rest), do: format_address_for_postgres_json(rest)
  def format_address_for_postgres_json(address), do: "\\x" <> address

  @doc "Standardise addresses for event streaming"
  def format_address_for_streaming(%Hash{} = address),
    do: address |> to_string() |> String.downcase()

  def format_address_for_streaming(nil), do: ""
  def format_address_for_streaming("\\x" <> rest), do: ("0x" <> rest) |> String.downcase()
  def format_address_for_streaming("0x" <> _rest = address), do: address |> String.downcase()
  def format_address_for_streaming(address), do: ("0x" <> address) |> String.downcase()

  @doc "Alias for format_address_for_postgres_json/1"
  defdelegate fa(address), to: __MODULE__, as: :format_address_for_postgres_json

  @doc "Convert postgres hex string to Explorer.Chain.Hash.Address instance"
  def cast_address("\\x" <> hash) do
    {:ok, address} = Address.cast("0x" <> hash)
    address
  end

  @doc "Alias for cast_address/1"
  defdelegate ca(address), to: __MODULE__, as: :cast_address

  # sobelow_skip ["DOS.StringToAtom"]
  @doc "Ensure that map has atom keys (not json string)"
  def normalise_map(map) do
    needs_conversion =
      map
      |> Map.keys()
      |> Enum.all?(&(!is_atom(&1)))

    if needs_conversion do
      map |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
    else
      map
    end
  end
end
