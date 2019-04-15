defmodule Indexer.Transform.Validators do
  @moduledoc """
  Helper functions for transformations of validators change log.
  """

  require Logger

  alias ABI.TypeDecoder
  alias Explorer.SmartContract.Reader

  @doc """
  Returns a list of validators given a list of logs.
  """
  def parse(logs) do
    event_method = "InitiateChange(bytes32,address[])"
    topic = "0x" <> Base.encode16(:keccakf1600.hash(:sha3_256, event_method), case: :lower)

    logs
    |> IO.inspect()
    |> Enum.filter(&(&1.first_topic == topic))
    |> IO.inspect()
    |> Enum.map(&do_parse/1)
    |> Enum.reject(&is_nil/1)
    |> List.flatten()
  end

  defp do_parse(log) do
    parse_params(log)
  rescue
    _ in [FunctionClauseError, MatchError] ->
      Logger.error(fn -> "Unknown InitiateChange log format: #{inspect(log)}" end)
      try_fetch_validators()
  end

  defp try_fetch_validators() do
    fetch_validators_list()
    |> fetch_validators_metadata()
  rescue
    err in [FunctionClauseError, MatchError] ->
      Logger.error(fn -> "Failed to fetch validators: #{inspect(err)}" end)
      nil
  end

  defp parse_params(%{second_topic: second_topic, third_topic: nil, fourth_topic: nil} = log)
       when not is_nil(second_topic) do
    [addresses] = decode_data(log.data, [{:array, :address}])

    addresses
    |> fetch_validators_metadata()
  end

  defp decode_data("0x", types) do
    for _ <- types, do: nil
  end

  defp decode_data("0x" <> encoded_data, types) do
    encoded_data
    |> Base.decode16!(case: :mixed)
    |> TypeDecoder.decode_raw(types)
  end

  defp fetch_validators_metadata(validators) do
    Enum.map(validators, fn validator ->
      validator
      |> fetch_validator_metadata
      |> translate_metadata
      |> Map.merge(%{address_hash: validator})
    end)
  end

  defp fetch_validators_list do
    %{"getValidators" => {:ok, [validators]}} =
      Reader.query_contract(config(:validators_contract_address), contract_abi("validators.json"), %{
        "getValidators" => []
      })

    validators
  end

  defp fetch_validator_metadata(validator_address) do
    response = Reader.query_contract(config(:metadata_contract_address), contract_abi("metadata.json"), %{
      "validators" => [validator_address]
    })

    case response do
      %{"validators" => {:ok, fields}} ->
        fields

      _ ->
        []
    end
  end

  defp translate_metadata([]) do
    %{
      name: "anonymous",
      metadata: %{
        active: true,
        type: "validator"
      }
    }
  end

  defp translate_metadata([
    first_name,
    last_name,
    license_id,
    full_address,
    state,
    zipcode,
    expiration_date,
    created_date,
    _updated_date,
    _min_treshold
  ]) do
    %{
      name: trim_null_bytes(first_name) <> " " <> trim_null_bytes(last_name),
      metadata: %{
        license_id: trim_null_bytes(license_id),
        address: full_address,
        state: trim_null_bytes(state),
        zipcode: trim_null_bytes(zipcode),
        expiration_date: expiration_date,
        created_date: created_date,
        active: true,
        type: "validator"
      }
    }
  end

  defp trim_null_bytes(bytes) do
    String.trim_trailing(bytes, <<0>>)
  end

  defp config(key) do
    Application.get_env(:indexer, __MODULE__, [])[key]
  end

  defp contract_abi(file_name) do
    :indexer
    |> Application.app_dir("priv/validator_contracts_abi/#{file_name}")
    |> File.read!()
    |> Jason.decode!()
  end
end
