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
      initial_acc = %{accounts: []}

      logs
      |> Enum.filter(&(&1.first_topic == unquote(CeloAccount.validator_registered_event())))
      |> Enum.reduce(initial_acc, &do_parse/2)
    end

    defp do_parse(log, %{accounts: accounts} = acc) do
      {account} = parse_params(log)
  
      %{
        accounts: [account | accounts]
      }
    rescue
      _ in [FunctionClauseError, MatchError] ->
        Logger.error(fn -> "Unknown account event format: #{inspect(log)}" end)
        acc
    end

    defp parse_params(%{second_topic: validator_address, third_topic: nil, fourth_topic: nil, data: _data} = _log) do
        account = %{
            address: truncate_address_hash(validator_address)
        }
        {account}
    end

    defp truncate_address_hash(nil), do: "0x0000000000000000000000000000000000000000"

    defp truncate_address_hash("0x000000000000000000000000" <> truncated_hash) do
      "0x#{truncated_hash}"
    end

end
