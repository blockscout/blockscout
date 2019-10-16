defmodule Indexer.Transform.CeloAccounts do
    @moduledoc """
    Helper functions for transforming data for Celo accounts.
    """
  
    require Logger
  
    alias ABI.TypeDecoder
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

    defp parse_params(%{second_topic: nil, third_topic: nil, fourth_topic: nil, data: data} = _log) when not is_nil(data) do
        [validator_address] = decode_data(data, [:address])
        account = %{
            address: validator_address
        }
        {account}
    end

    defp decode_data("0x", types) do
        for _ <- types, do: nil
    end

    defp decode_data("0x" <> encoded_data, types) do
        encoded_data
        |> Base.decode16!(case: :mixed)
        |> TypeDecoder.decode_raw(types)
    end

end
