defmodule Explorer.Celo.AccountReader do
  @moduledoc """
  Reads information about Celo accounts using Smart Contract functions from the blockchain.
  """

  require Logger
  alias Explorer.Celo.AbiHandler
  alias Explorer.SmartContract.Reader

  use Bitwise

  def account_data(%{address: account_address}) do
    data = fetch_account_data(account_address)

    with {:ok, [name]} <- data["getName"],
         {:ok, [url]} <- data["getMetadataURL"],
         {:ok, [is_validator]} <- data["isValidator"],
         {:ok, [usd]} <- data["balanceOf"],
         {:ok, [is_validator_group]} <- data["isValidatorGroup"],
         account_type = determine_account_type(is_validator, is_validator_group),
         {:ok, [gold]} <- data["getAccountTotalLockedGold"],
         {:ok, [nonvoting_gold]} <- data["getAccountNonvotingLockedGold"] do
      {:ok,
       %{
         address: account_address,
         name: name,
         url: url,
         usd: usd,
         locked_gold: gold,
         nonvoting_locked_gold: nonvoting_gold,
         account_type: account_type
       }}
    else
      _ ->
        :error
    end
  end

  def is_validator_group(address) do
    data = call_methods([{:validators, "isValidatorGroup", [address]}])

    case data["isValidatorGroup"] do
      {:ok, [res]} -> {:ok, res}
      _ -> :error
    end
  end

  def validator_group_members(address) do
    data = call_methods([{:validators, "getValidatorGroup", [address]}])

    case data["getValidatorGroup"] do
      {:ok, [res | _]} -> {:ok, res}
      _ -> :error
    end
  end

  def validator_group_reward_data(address, bn) do
    data =
      call_methods([
        {:election, "getActiveVotesForGroup", [address], bn},
        {:epochrewards, "calculateTargetEpochRewards", [], bn},
        {:election, "getActiveVotes", [], bn}
      ])

    with {:ok, [active_votes]} <- data["getActiveVotesForGroup"],
         {:ok, [total_active_votes]} <- data["getActiveVotes"],
         {:ok, [_ | [total_reward | _]]} <- data["calculateTargetEpochRewards"] do
      {:ok, %{active_votes: active_votes, total_active_votes: total_active_votes, total_reward: total_reward}}
    else
      _ -> :error
    end
  end

  @spec validator_data(String.t()) ::
          {:ok,
           %{
             address: String.t(),
             group_address_hash: String.t(),
             score: Decimal.t(),
             signer_address_hash: String.t(),
             member: integer
           }}
          | :error
  def validator_data(address) do
    data = fetch_validator_data(address)

    case data["getValidator"] do
      {:ok, [_, _, affiliation, score, signer]} ->
        {:ok,
         %{
           address: address,
           group_address_hash: affiliation,
           score: score,
           signer_address_hash: signer,
           member: fetch_group_membership(address, affiliation)
         }}

      _ ->
        :error
    end
  end

  def validator_group_data(address) do
    data = fetch_validator_group_data(address)

    with {:ok, [_ | [commission | _]]} <- data["getValidatorGroup"],
         {:ok, [active_votes]} <- data["getActiveVotesForGroup"],
         {:ok, [num_members]} <- data["getGroupNumMembers"],
         {:ok, [votes]} <- data["getTotalVotesForGroup"] do
      {:ok,
       %{
         address: address,
         votes: votes,
         active_votes: active_votes,
         num_members: num_members,
         commission: commission
       }}
    else
      _ ->
        :error
    end
  end

  defp fetch_validator_group_data(address) do
    call_methods([
      {:election, "getTotalVotesForGroup", [address]},
      {:election, "getActiveVotesForGroup", [address]},
      {:validators, "getGroupNumMembers", [address]},
      {:validators, "getValidatorGroup", [address]}
    ])
  end

  def voter_data(group_address, voter_address) do
    data =
      call_methods([
        {:election, "getPendingVotesForGroupByAccount", [group_address, voter_address]},
        {:election, "getTotalVotesForGroupByAccount", [group_address, voter_address]},
        {:election, "getActiveVotesForGroupByAccount", [group_address, voter_address]}
      ])

    with {:ok, [pending]} <- data["getPendingVotesForGroupByAccount"],
         {:ok, [total]} <- data["getTotalVotesForGroupByAccount"],
         {:ok, [active]} <- data["getActiveVotesForGroupByAccount"] do
      {:ok,
       %{
         group_address_hash: group_address,
         voter_address_hash: voter_address,
         total: total,
         pending: pending,
         active: active
       }}
    else
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

  defp get_index(bm, idx) do
    byte = :binary.at(bm, 31 - floor(idx / 8))

    if (byte >>> (7 - rem(255 - idx, 8)) &&& 1) == 1 do
      true
    else
      false
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
      {:usd, "balanceOf", [account_address]},
      {:accounts, "getMetadataURL", [account_address]}
    ])
  end

  defp fetch_group_membership(account_address, group_address) do
    data =
      call_methods([
        {:validators, "getValidatorGroup", [group_address]}
      ])

    case data["getValidatorGroup"] do
      {:ok, [members | _]} ->
        idx =
          members
          |> Enum.zip(1..1000)
          |> Enum.filter(fn {addr, _} ->
            String.downcase(account_address) == "0x" <> Base.encode16(addr, case: :lower)
          end)
          |> Enum.map(fn {_, idx} -> idx end)

        case idx do
          [order] -> order
          _ -> -1
        end

      _ ->
        -1
    end
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

  def validator_history(block_number) do
    data = fetch_validators(block_number)

    with {:ok, [bm]} <- data["getParentSealBitmap"],
         {:ok, [num_validators]} <- data["getNumRegisteredValidators"],
         {:ok, [min_validators, max_validators]} <- data["getElectableValidators"],
         {:ok, [total_gold]} <- data["getTotalLockedGold"],
         {:ok, [epoch_size]} <- data["getEpochSize"],
         {:ok, gold_address} <- get_address("GoldToken"),
         {:ok, usd_address} <- get_address("StableToken"),
         {:ok, oracle_address} <- get_address("SortedOracles"),
         {:ok, [validators]} <- data["getCurrentValidatorSigners"] do
      list =
        validators
        |> Enum.with_index()
        |> Enum.map(fn {addr, idx} -> %{address: addr, index: idx, online: get_index(bm, idx)} end)
      
      debug = Enum.filter(list, fn a -> not a.online end)

      IO.inspect(%{block_number: block_number, down: Enum.count(debug)})

      params = [
        %{name: "numRegisteredValidators", number_value: num_validators},
        %{name: "totalLockedGold", number_value: total_gold},
        %{name: "stableToken", address_value: usd_address},
        %{name: "goldToken", address_value: gold_address},
        %{name: "sortedOracles", address_value: oracle_address},
        %{name: "maxElectableValidators", number_value: max_validators},
        %{name: "minElectableValidators", number_value: min_validators},
        %{name: "epochSize", number_value: epoch_size}
      ]

      {:ok, %{validators: list, params: params, block_number: block_number-1}}
    else
      _ ->
        :error
    end
  end

  defp fetch_validators(bn) do
    call_methods([
      {:election, "getCurrentValidatorSigners", [], bn - 1},
      {:election, "getParentSealBitmap", [bn], bn},
      {:election, "getEpochSize", []},
      {:election, "getElectableValidators", []},
      {:lockedgold, "getTotalLockedGold", []},
      {:validators, "getNumRegisteredValidators", []}
    ])
  end

  defp fetch_withdrawal_data(address) do
    call_methods([{:lockedgold, "getPendingWithdrawals", [address]}])
  end

  defp call_methods(methods) do
    contract_abi = AbiHandler.get_abi()

    methods
    |> Enum.map(&format_request/1)
    |> Enum.filter(fn req -> req.contract_address != :error end)
    |> Enum.map(fn %{contract_address: {:ok, address}} = req -> Map.put(req, :contract_address, address) end)
    |> Reader.query_contracts(contract_abi)
    |> Enum.zip(methods)
    |> Enum.into(%{}, fn
      {response, {_, function_name, _}} -> {function_name, response}
      {response, {_, function_name, _, _}} -> {function_name, response}
    end)
  end

  defp format_request({contract_name, function_name, params}) do
    %{
      contract_address: contract(contract_name),
      function_name: function_name,
      args: params
    }
  end

  defp format_request({contract_name, function_name, params, bn}) do
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
  defp contract(:epochrewards), do: get_address("EpochRewards")
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
