defmodule Indexer.Transform.Validators do
  @moduledoc """
  Helper functions for transformations of validators change log.
  """

  require Logger

  alias ABI.TypeDecoder
  alias Explorer.Validator.MetadataRetriever

  @doc """
  Returns a list of validators given a list of logs.
  """
  def parse(logs) do
    event_method = "InitiateChange(bytes32,address[])"
    topic = "0x" <> Base.encode16(:keccakf1600.hash(:sha3_256, event_method), case: :lower)

    logs
    |> Enum.filter(&(&1.first_topic == topic))
    |> Enum.map(&do_parse/1)
    |> Enum.reject(&is_nil/1)
    |> List.flatten()
  end

  defp do_parse(log) do
    parse_params(log)
  rescue
    _ in [FunctionClauseError, MatchError] ->
      Logger.error(fn -> "Unknown InitiateChange log format: #{inspect(log)}" end)
      nil
  end

  defp parse_params(%{second_topic: second_topic, third_topic: nil, fourth_topic: nil} = log)
       when not is_nil(second_topic) do
    [addresses] = decode_data(log.data, [{:array, :address}])

    MetadataRetriever.fetch_validators_metadata(addresses)
  end

  defp decode_data("0x", types) do
    for _ <- types, do: nil
  end

  defp decode_data("0x" <> encoded_data, types) do
    encoded_data
    |> Base.decode16!(case: :mixed)
    |> TypeDecoder.decode_raw(types)
  end

end
