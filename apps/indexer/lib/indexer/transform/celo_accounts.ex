defmodule Indexer.Transform.CeloAccounts do
    @moduledoc """
    Helper functions for transforming data for Celo accounts.
    """
  
    require Logger
  
    alias Explorer.Chain.CeloAccount

    @doc """
    Returns a list of account addresses given a list of logs.
    """
    def parse(logs) do
      accounts = logs
      |> Enum.filter(fn log ->
        Enum.member?(CeloAccount.account_events(), log.first_topic)
      end)
      |> Enum.reduce([], &do_parse/2)
      |> Enum.map(fn address -> %{address: address} end)

      validators = logs
      |> Enum.filter(fn log ->
        Enum.member?(CeloAccount.validator_events(), log.first_topic)
      end)
      |> Enum.reduce([], &do_parse/2)
      |> Enum.map(fn address -> %{address: address} end)

      validator_groups = logs
      |> Enum.filter(fn log ->
        Enum.member?(CeloAccount.validator_group_events(), log.first_topic)
      end)
      |> Enum.reduce([], &do_parse/2)
      |> Enum.map(fn address -> %{address: address} end)

      withdrawals = logs
      |> Enum.filter(fn log ->
        Enum.member?(CeloAccount.withdrawal_events(), log.first_topic)
      end)
      |> Enum.reduce([], &do_parse/2)
      |> Enum.map(fn address -> %{address: address} end)

      # IO.inspect(accounts)

      %{accounts: accounts, validators: validators, validator_groups: validator_groups, withdrawals: withdrawals}
    end

    defp do_parse(log, accounts) do
      account_address = parse_params(log)
      IO.inspect(log)
  
      if Enum.member?(accounts, account_address) do accounts
      else [account_address | accounts] end

    rescue
      _ in [FunctionClauseError, MatchError] ->
        Logger.error(fn -> "Unknown account event format: #{inspect(log)}" end)
        accounts
    end

    defp parse_params(%{second_topic: validator_address, third_topic: _topic3, fourth_topic: _topic4, data: _data} = _log) do
      truncate_address_hash(validator_address)
    end

    defp truncate_address_hash(nil), do: "0x0000000000000000000000000000000000000000"

    defp truncate_address_hash("0x000000000000000000000000" <> truncated_hash) do
      "0x#{truncated_hash}"
    end

end
