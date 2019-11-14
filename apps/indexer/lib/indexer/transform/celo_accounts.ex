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
    %{
      accounts: get_addresses(logs, CeloAccount.account_events()),
      validators: get_addresses(logs, CeloAccount.validator_events()),
      validator_groups: get_addresses(logs, CeloAccount.validator_group_events()),
      withdrawals: get_addresses(logs, CeloAccount.withdrawal_events())
    }
  end

  defp get_addresses(logs, topics) do
    logs
    |> Enum.filter(fn log -> Enum.member?(topics, log.first_topic) end)
    |> Enum.reduce([], &do_parse/2)
    |> Enum.map(fn address -> %{address: address} end)
  end

  defp do_parse(log, accounts) do
    account_address = parse_params(log)

    if Enum.member?(accounts, account_address) do
      accounts
    else
      [account_address | accounts]
    end
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
