defmodule Explorer.Validator.MetadataRetriever do
  @moduledoc """
  Consults the configured smart contracts to fetch the validators' metadata
  """

  alias Explorer.SmartContract.Reader

  def fetch_data do
    fetch_validators_list()
    |> Enum.map(fn validator ->
      validator
      |> fetch_validator_metadata_by_id
      |> translate_posdao_metadata
      |> Map.merge(%{address_hash: validator, primary: true})
    end)
  end

  def fetch_validators_list do
    validators_contract_address = config(:validators_contract_address)

    validators_contract_address_checked =
      if is_nil(validators_contract_address) and Mix.env() == :test do
        "0x0000000000000000000000000000000000006001"
      else
        validators_contract_address
      end

    # b7ab4db5 = keccak256(getValidators())
    with false <- is_nil(validators_contract_address_checked),
         %{"b7ab4db5" => {:ok, [validators]}} <-
           Reader.query_contract(
             validators_contract_address_checked,
             contract_abi("validators.json"),
             %{"b7ab4db5" => []},
             false
           ) do
      validators
    else
      _ -> []
    end
  end

  # deprecated
  # defp fetch_validator_metadata(validator_address) do
  #   # fa52c7d8 = keccak256(validators(address))
  #   %{"fa52c7d8" => {:ok, fields}} =
  #     Reader.query_contract(config(:metadata_contract_address), contract_abi("metadata.json"), %{
  #       "fa52c7d8" => [validator_address]
  #     },
  #     false
  #     )

  #   fields
  # end

  defp fetch_validator_metadata_by_id(validator_address) do
    # 2bbb7b72 = keccak256(idByMiningAddress(address))
    %{"2bbb7b72" => {:ok, [validator_id]}} =
      Reader.query_contract(
        config(:validators_contract_address),
        contract_abi("posdao", "ValidatorSetAuRa.json"),
        %{
          "2bbb7b72" => [validator_address]
        },
        false
      )

    # cccf3a02 = keccak256(poolName(uint256))
    %{"cccf3a02" => {:ok, [validator_name]}} =
      Reader.query_contract(
        config(:validators_contract_address),
        contract_abi("posdao", "ValidatorSetAuRa.json"),
        %{
          "cccf3a02" => [validator_id]
        },
        false
      )

    validator_name
  end

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
  #        _min_threshold
  #      ]) do
  #       %{
  #         name: name,
  #         metadata: nil
  #       }
  # end

  defp translate_posdao_metadata(name) do
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

  # sobelow_skip ["Traversal"]
  defp contract_abi(file_name) do
    :explorer
    |> Application.app_dir("priv/contracts_abi/poa/#{file_name}")
    |> File.read!()
    |> Jason.decode!()
  end
end
