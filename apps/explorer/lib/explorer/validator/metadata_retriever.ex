defmodule Explorer.Validator.MetadataRetriever do
  @moduledoc """
  Consults the configured smart contracts to fetch the valivators' metadata
  """

  alias Explorer.SmartContract.Reader

  def fetch_data do
    fetch_validators_list()
    |> fetch_validators_metadata()
  end

  def fetch_validators_metadata(validators) do
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
    response =
      Reader.query_contract(config(:metadata_contract_address), contract_abi("metadata.json"), %{
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
    Application.get_env(:explorer, __MODULE__, [])[key]
  end

  # sobelow_skip ["Traversal"]
  defp contract_abi(file_name) do
    :explorer
    |> Application.app_dir("priv/validator_contracts_abi/#{file_name}")
    |> File.read!()
    |> Jason.decode!()
  end
end
