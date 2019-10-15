defmodule Explorer.Staking.AccountReader do
  @moduledoc """
  Reads information about Celo accounts using Smart Contract functions from the blockchain.
  """
  alias Explorer.SmartContract.Reader

  def account_data(account_address) do
    with data = fetch_account_data(account_address),
         {:ok, [is_validator]} <- data["isValidator"],
         {:ok, [is_validator_group]} <- data["isValidatorGroup"],
         account_type = determine_account_type(is_validator, is_validator_group),
         {:ok, [gold]} <- data["getAccountWeight"] do
      {
        :ok,
        %{
          address: account_address,
          gold: 0,
          usd: 0,
          notice_period: 0,
          rewards: 0,
          locked_gold: gold,
          account_type: account_type,
        }
      }
    else
      _ ->
        :error
    end
  end

  defp determine_account_type(is_validator, is_validator_group) do
    if is_validator do "validator"
    else
      if is_validator_group do "group"
      else "normal"
      end
    end
  end

  defp fetch_account_data(account_address) do
    call_methods([
      {:lockedgold, "getAccountWeight", [account_address]},
      {:validators, "isValidator", [account_address]},
      {:validators, "isValidatorGroup", [account_address]},
    ])
  end

  defp call_methods(methods) do
    contract_abi = abi("lockedgold.json") + abi("validators.json")
    methods
    |> Enum.map(&format_request/1)
    |> Reader.query_contracts(contract_abi)
    |> Enum.zip(methods)
    |> Enum.into(%{}, fn {response, {_, function_name, _}} ->
      {function_name, response}
    end)
  end

  defp format_request({contract_name, function_name, params}) do
    %{
      contract_address: contract(contract_name),
      function_name: function_name,
      args: params
    }
  end

  defp contract(:lockedgold), do: config(:lockedgold_contract_address)
  defp contract(:validators), do: config(:validators_contract_address)

  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end

  # sobelow_skip ["Traversal"]
  defp abi(file_name) do
    :explorer
    |> Application.app_dir("priv/contracts_abi/celo/#{file_name}")
    |> File.read!()
    |> Jason.decode!()
  end

end

