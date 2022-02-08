defmodule Explorer.Celo.ContractEvents.Common do
  @moduledoc "Common functionality for import in Celo contract event structs"

  alias ABI.TypeDecoder
  alias Explorer.Chain.Hash.Address
  alias Explorer.Chain.{Data, Hash}

  @doc "Decode a single point of event data of a given type from a given topic"
  def decode_event(topic, type) do
    topic
    |> extract_hash()
    |> TypeDecoder.decode_raw([type])
    |> List.first()
    |> convert_result(type)
  end

  @doc "Decode event data of given types from log data"
  def decode_data(%Data{bytes: bytes}, types), do: decode_data(bytes, types)

  def decode_data("0x" <> data, types) do
    data
    |> Base.decode16!(case: :lower)
    |> decode_data(types)
  end

  def decode_data(data, types) when is_binary(data), do: data |> TypeDecoder.decode_raw(types)

  defp extract_hash(event_data), do: event_data |> String.trim_leading("0x") |> Base.decode16!(case: :lower)

  defp convert_result(result, :address) do
    {:ok, address} = Address.cast(result)
    address
  end

  def extract_common_event_params(event) do
    # set hashes explicitly to nil rather than empty string when they do not exist
    [:transaction_hash, :contract_address_hash, :block_hash]
    |> Enum.into(%{}, fn key ->
      case Map.get(event, key) do
        nil -> {key, nil}
        v -> {key, v}
      end
    end)
    |> Map.put(:name, event.name)
    |> Map.put(:log_index, event.log_index)
  end

  @doc "Store address in postgres json format to make joins work with indices"
  def format_address_for_postgres_json(%Hash{} = address),
    do: address |> to_string() |> format_address_for_postgres_json()

  def format_address_for_postgres_json(nil), do: "\\x"
  def format_address_for_postgres_json("\\x" <> _rest = address), do: address
  def format_address_for_postgres_json("0x" <> rest), do: format_address_for_postgres_json(rest)
  def format_address_for_postgres_json(address), do: "\\x" <> address

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
