defmodule Explorer.Celo.AccountReader do
  @moduledoc """
  Reads information about Celo accounts using Smart Contract functions from the blockchain.
  """

  require Logger
  alias Explorer.Celo.AbiHandler
  alias Explorer.SmartContract.Reader

  def account_data(%{address: account_address}) do
    data = fetch_account_data(account_address)

    with {:ok, [name]} <- data["getName"],
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
         account_type: account_type
       }}
    else
      _ ->
        :error
    end
  end

  def validator_data(%{address: address}) do
    data = fetch_validator_data(address)

    case data["getValidator"] do
      {:ok, [_, _, affiliation, score, signer]} ->
        {:ok,
         %{
           address: address,
           group_address_hash: affiliation,
           score: score,
           signer_address_hash: signer
         }}

      _ ->
        :error
    end
  end

  def validator_group_data(%{address: address}) do
    data = fetch_validator_group_data(address)

    case data["getValidatorGroup"] do
      {:ok, [_members, commission, _size_history]} ->
        {:ok,
         %{
           address: address,
           commission: commission
         }}

      _ ->
        :error
    end
  end

  # how to delete them from the table?
  def withdrawal_data(%{address: address}) do
    data = fetch_withdrawal_data(address)

    case data["getPendingWithdrawals"] do
      {:ok, [values, timestamps]} ->
        {:ok,
         %{
           address: address,
           withdrawals:
             Enum.map(Enum.zip(values, timestamps), fn {v, t} -> %{address: address, amount: v, timestamp: t} end)
         }}

      _ ->
        :error
    end
  end

  def validator_history(block_number) do
    data = fetch_validators(block_number)

    case data["getCurrentValidatorSigners"] do
      {:ok, [validators]} ->
        list =
          validators
          |> Enum.with_index()
          |> Enum.map(fn {addr, idx} -> %{address: addr, index: idx} end)

        {:ok, %{validators: list}}

      _ ->
        :error
    end
  end

  defp determine_account_type(is_validator, is_validator_group) do
    if is_validator do
      "validator"
    else
      if is_validator_group do
        "group"
      else
        "normal"
      end
    end
  end

  defp fetch_account_data(account_address) do
    call_methods([
      {:lockedgold, "getAccountTotalLockedGold", [account_address]},
      {:lockedgold, "getAccountNonvotingLockedGold", [account_address]},
      {:validators, "isValidator", [account_address]},
      {:validators, "isValidatorGroup", [account_address]},
      {:accounts, "getName", [account_address]},
      {:accounts, "getMetadataURL", [account_address]}
    ])
  end

  def fetch_claimed_account_data(address) do
    call_methods([
      {:lockedgold, "getAccountTotalLockedGold", [address]},
      {:gold, "balanceOf", [address]}
    ])
  end

  def fetch_account_usd(address) do
    call_methods([{:usd, "balanceOf", [address]}])
  end

  defp fetch_validator_data(address) do
    data =
      call_methods([
        {:validators, "getValidator", [address]}
      ])

    data
  end

  defp fetch_validators(bn) do
    call_methods([{:election, "getCurrentValidatorSigners", []}], bn)
  end

  defp fetch_withdrawal_data(address) do
    call_methods([{:locked_gold, "getPendingWithdrawals", [address]}])
  end

  defp fetch_validator_group_data(address) do
    call_methods([
      {:validators, "getValidatorGroup", [address]}
    ])
  end

  defp call_methods(methods) do
    contract_abi = AbiHandler.get_abi()

    methods
    |> Enum.map(&format_request/1)
    |> Enum.filter(fn req -> req.contract_address != :error end)
    |> Enum.map(fn %{contract_address: {:ok, address}} = req -> Map.put(req, :contract_address, address) end)
    |> Reader.query_contracts(contract_abi)
    |> Enum.zip(methods)
    |> Enum.into(%{}, fn {response, {_, function_name, _}} ->
      {function_name, response}
    end)
  end

  defp call_methods(methods, bn) do
    contract_abi = AbiHandler.get_abi()

    methods
    |> Enum.map(fn a -> format_request(a, bn) end)
    |> Enum.filter(fn req -> req.contract_address != :error end)
    |> Enum.map(fn %{contract_address: {:ok, address}} = req -> Map.put(req, :contract_address, address) end)
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

  defp format_request({contract_name, function_name, params}, bn) do
    %{
      contract_address: contract(contract_name),
      function_name: function_name,
      args: params,
      block_number: bn
    }
  end

  defp contract(:lockedgold), do: get_address("LockedGold")
  defp contract(:validators), do: get_address("Validators")
  defp contract(:election), do: get_address("Election")
  defp contract(:accounts), do: get_address("Accounts")
  defp contract(:gold), do: get_address("GoldToken")
  defp contract(:usd), do: get_address("StableToken")

  def get_address(name) do
    case get_address_raw(name) do
      {:ok, address} -> {:ok, "0x" <> Base.encode16(address, case: :lower)}
      _ -> :error
    end
  end

  def get_address_raw(name) do
    contract_abi = AbiHandler.get_abi()

    methods = [
      %{
        contract_address: "0x000000000000000000000000000000000000ce10",
        function_name: "getAddressForString",
        args: [name]
      }
    ]

    res =
      methods
      |> Reader.query_contracts(contract_abi)
      |> Enum.zip(methods)
      |> Enum.into(%{}, fn {response, %{function_name: function_name}} ->
        {function_name, response}
      end)

    case res["getAddressForString"] do
      {:ok, [address]} -> {:ok, address}
      _ -> :error
    end
  end
end
