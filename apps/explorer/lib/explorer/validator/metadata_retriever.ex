defmodule Explorer.Validator.MetadataRetriever do
  @moduledoc """
  Consults the configured smart contracts to fetch the valivators' metadata
  """

  alias Explorer.SmartContract.Reader

  def fetch_data do
    fetch_validators_list()
    |> Enum.map(fn validator ->
      validator
      |> fetch_validator_metadata_by_id
      |> transalate_posdao_metadata
      |> Map.merge(%{address_hash: validator, primary: true})
    end)
  end

  def fetch_validators_list do
    # b7ab4db5 = keccak256(getValidators())
    case Reader.query_contract(config(:validators_contract_address), contract_abi("poa", "validators.json"), %{
           "b7ab4db5" => []
         }) do
      %{"b7ab4db5" => {:ok, [validators]}} -> validators
      _ -> []
    end
  end

  # deprecated
  # defp fetch_validator_metadata(validator_address) do
  #   # fa52c7d8 = keccak256(validators(address))
  #   %{"fa52c7d8" => {:ok, fields}} =
  #     Reader.query_contract(config(:metadata_contract_address), contract_abi("metadata.json"), %{
  #       "fa52c7d8" => [validator_address]
  #     })

  #   fields
  # end

  defp fetch_validator_metadata_by_id(validator_address) do
    # 2bbb7b72 = keccak256(idByMiningAddress(address))
    %{"2bbb7b72" => {:ok, [validator_id]}} =
      Reader.query_contract(config(:validators_contract_address), contract_abi("posdao", "ValidatorSetAuRa.json"), %{
        "2bbb7b72" => [validator_address]
      })

    # cccf3a02 = keccak256(poolName(uint256))
    %{"cccf3a02" => {:ok, [validator_name]}} =
      Reader.query_contract(config(:validators_contract_address), contract_abi("posdao", "ValidatorSetAuRa.json"), %{
        "cccf3a02" => [validator_id]
      })

    validator_name
  end

  # deprecated
  # defp translate_metadata([
  #        first_name,
  #        last_name,
  #        license_id,
  #        full_address,
  #        state,
  #        zipcode,
  #        expiration_date,
  #        created_date,
  #        _updated_date,
  #        _min_treshold
  #      ]) do
  #   %{
  #     name: trim_null_bytes(first_name) <> " " <> trim_null_bytes(last_name),
  #     metadata: %{
  #       license_id: trim_null_bytes(license_id),
  #       address: full_address,
  #       state: trim_null_bytes(state),
  #       zipcode: trim_null_bytes(zipcode),
  #       expiration_date: expiration_date,
  #       created_date: created_date
  #     }
  #   }
  # end

  defp transalate_posdao_metadata(name) do
    %{
      name: name,
      metadata: nil
    }
  end

  # deprecated
  # defp trim_null_bytes(bytes) do
  #   String.trim_trailing(bytes, <<0>>)
  # end

  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end

  # sobelow_skip ["Traversal"]
  defp contract_abi(folder, file_name) do
    :explorer
    |> Application.app_dir("priv/contracts_abi/#{folder}/#{file_name}")
    |> File.read!()
    |> Jason.decode!()
  end
end
