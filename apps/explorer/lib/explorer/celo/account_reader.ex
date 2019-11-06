defmodule Explorer.Celo.AccountReader do
  @moduledoc """
  Reads information about Celo accounts using Smart Contract functions from the blockchain.
  """
  alias Explorer.SmartContract.Reader

  require Logger

  def account_data(%{address: account_address}) do
    with data = fetch_account_data(account_address),
        {:ok, [name]} <- data["getName"],
        {:ok, [url]} <- data["getMetadataURL"],
        {:ok, [is_validator]} <- data["isValidator"],
        {:ok, [is_validator_group]} <- data["isValidatorGroup"],
         account_type = determine_account_type(is_validator, is_validator_group),
         {:ok, [gold]} <- data["getAccountTotalLockedGold"],
         {:ok, [nonvoting_gold]} <- data["getAccountNonvotingLockedGold"] do
        {:ok,
        %{
          address: account_address,
          name: name,
          url: url,
          rewards: 0,
          locked_gold: gold,
          nonvoting_locked_gold: nonvoting_gold,
          account_type: account_type,
        }
      }
    else
      _ ->
        :error
    end
  end

  def validator_data(%{address: address}) do
    with data = fetch_validator_data(address),
      {:ok, [_, affiliation, score]} <- data["getValidator"] do
     {:ok,
      %{
        address: address,
        group_address_hash: affiliation,
        score: score,
      }
     }
     else  _ -> :error end
  end

  def validator_group_data(%{address: address}) do
    with data = fetch_validator_group_data(address),
      {:ok, [_members, commission, _size_history]} <- data["getValidatorGroup"] do
     {:ok,
      %{
        address: address,
        commission: commission
      }
     }
     else  _ -> :error end
  end

  # how to delete them from the table?
  def withdrawal_data(%{address: address}) do
    with data = fetch_withdrawal_data(address),
      {:ok, [values, timestamps]} <- data["getPendingWithdrawals"] do
     {:ok,
      %{
        address: address,
        withdrawals:
          Enum.zip(values, timestamps) |>
          Enum.map(fn (v,t) -> %{address: address, amount: v, timestamp: t} end)
      }
     }
     else  _ -> :error end
  end

  def validator_history(%{block_number: _block_number}) do
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
    data = call_methods([
      {:lockedgold, "getAccountTotalLockedGold", [account_address]},
      {:lockedgold, "getAccountNonvotingLockedGold", [account_address]},
      {:validators, "isValidator", [account_address]},
      {:validators, "isValidatorGroup", [account_address]},
      {:accounts, "getName", [account_address]},
      {:accounts, "getMetadataURL", [account_address]},
    ])
    IO.inspect(data)
    data
  end

  defp fetch_validator_data(address) do
    data = call_methods([
      {:validators, "getValidator", [address]},
    ])
    IO.inspect(address)
    IO.inspect(data)
    data
  end

  defp fetch_withdrawal_data(address) do
    data = call_methods([{:locked_gold, "getPendingWithdrawals", [address]}])
    IO.inspect(data)
    data
  end

  defp fetch_validator_group_data(address) do
    data = call_methods([
      {:validators, "getValidatorGroup", [address]},
    ])
    IO.inspect(data)
    data
  end

  defp call_methods(methods) do
    contract_abi = abi("lockedgold.json") ++ abi("validators.json") ++ abi("election.json") ++ abi("accounts.json")
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
  defp contract(:election), do: config(:election_contract_address)
  defp contract(:accounts), do: config(:accounts_contract_address)

  defp config(key) do
    data = Application.get_env(:explorer, __MODULE__, [])[key]
    data
  end

  # sobelow_skip ["Traversal"]
  defp abi(file_name) do
    :explorer
    |> Application.app_dir("priv/contracts_abi/celo/#{file_name}")
    |> File.read!()
    |> Jason.decode!()
  end

end

