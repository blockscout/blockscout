defmodule Indexer.Transform.CeloAccounts do
  @moduledoc """
  Helper functions for transforming data for Celo accounts.
  """

  require Logger

  alias ABI.TypeDecoder
  alias Explorer.Chain.{CeloAccount, CeloSigners}

  @doc """
  Returns a list of account addresses given a list of logs.
  """
  def parse(logs) do
    %{
      accounts: get_addresses(logs, CeloAccount.account_events()),
      validators: get_addresses(logs, CeloAccount.validator_events()),
      validator_groups: get_addresses(logs, CeloAccount.validator_group_events()),
      withdrawals: get_addresses(logs, CeloAccount.withdrawal_events()),
      signers: get_signers(logs, CeloSigners.signer_events()),
      attestations_fulfilled:
        get_addresses(logs, [CeloAccount.attestation_completed_event()], fn a -> a.fourth_topic end),
      attestations_requested:
        get_addresses(logs, [CeloAccount.attestation_issuer_selected_event()], fn a -> a.fourth_topic end)
    }
  end

  defp get_addresses(logs, topics, get_topic \\ fn a -> a.second_topic end) do
    logs
    |> Enum.filter(fn log -> Enum.member?(topics, log.first_topic) end)
    |> Enum.reduce([], fn log, accounts -> do_parse(log, accounts, get_topic) end)
    |> Enum.map(fn address -> %{address: address} end)
  end

  defp get_signers(logs, topics) do
    logs
    |> Enum.filter(fn log -> Enum.member?(topics, log.first_topic) end)
    |> Enum.reduce([], fn log, accounts -> do_parse_signers(log, accounts) end)
  end

  defp do_parse(log, accounts, get_topic) do
    account_address = parse_params(log, get_topic)

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

  defp do_parse_signers(log, accounts) do
    IO.inspect(log)
    signer_pair = parse_signer_params(log)
    [signer_pair | accounts]
  rescue
    _ in [FunctionClauseError, MatchError] ->
      Logger.error(fn -> "Unknown signer authorization event format: #{inspect(log)}" end)
      accounts
  end

  defp parse_params(log, get_topic) do
    truncate_address_hash(get_topic.(log))
  end

  defp parse_signer_params(log) do
    address = truncate_address_hash(log.second_topic)
    [signer] = decode_data(log.data, [:address])
    %{address: address, signer: signer}
  end

  defp truncate_address_hash(nil), do: "0x0000000000000000000000000000000000000000"

  defp truncate_address_hash("0x000000000000000000000000" <> truncated_hash) do
    "0x#{truncated_hash}"
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
