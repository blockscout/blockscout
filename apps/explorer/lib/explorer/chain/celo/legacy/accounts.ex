defmodule Explorer.Chain.Celo.Legacy.Accounts do
  @moduledoc """
  Helper functions for transforming data for Celo accounts.

  TODO: this implementation is ported from the celo's fork of blockscout and
  could be improved in the future.
  """

  require Logger

  alias ABI.TypeDecoder
  alias Explorer.Chain.Celo.Legacy.Events

  @max_name_length 30

  @doc """
  Returns a list of account addresses given a list of logs.
  """
  def parse(logs) do
    logs =
      logs
      |> Enum.map(
        &Map.merge(&1, %{
          first_topic: to_string(&1.first_topic),
          second_topic: to_string(&1.second_topic),
          third_topic: to_string(&1.third_topic),
          fourth_topic: to_string(&1.fourth_topic),
          data: to_string(&1.data)
        })
      )

    %{
      # Add special items for voter epoch rewards
      accounts: get_addresses(logs, Events.account_events()),
      # Adding a group to updated validators means to update all members of the group
      validators:
        get_addresses(logs, Events.validator_events()) ++
          get_addresses(logs, Events.membership_events()) ++
          get_addresses(logs, Events.membership_events(), fn a -> a.third_topic end),
      account_names: get_names(logs),
      validator_groups:
        get_addresses(logs, Events.validator_group_events()) ++
          get_addresses(logs, Events.vote_events(), fn a -> a.third_topic end),
      withdrawals: [get_withdrawal_events(logs, Events.gold_withdrawn())],
      unlocked: [get_withdrawal_events(logs, Events.gold_unlocked())],
      signers: get_signers(logs, Events.signer_events()),
      voters: get_voters(logs, Events.voter_events()),
      attestations_fulfilled: get_addresses(logs, [Events.attestation_completed_event()], fn a -> a.fourth_topic end),
      attestations_requested:
        get_addresses(logs, [Events.attestation_issuer_selected_event()], fn a -> a.fourth_topic end),
      wallets: get_wallets(logs)
    }
  end

  def get_names(logs) do
    logs
    |> Enum.filter(fn log -> log.first_topic == Events.account_name_event() end)
    |> Enum.reduce([], fn log, names -> do_parse_name(log, names) end)
    |> Enum.filter(fn %{name: name} -> String.length(name) > 0 end)
  end

  defp get_addresses(logs, topics, get_topic \\ fn a -> a.second_topic end) do
    logs
    |> Enum.filter(fn log -> Enum.member?(topics, log.first_topic) end)
    |> Enum.reduce([], fn log, accounts -> do_parse(log, accounts, get_topic) end)
  end

  defp get_withdrawal_events(logs, topics) do
    logs
    |> Enum.filter(fn log -> Enum.member?(topics, log.first_topic) end)
    |> Enum.reduce([], fn log, accounts -> do_parse_withdrawal_events(log, accounts, fn a -> a.second_topic end) end)
  end

  defp get_signers(logs, topics) do
    logs
    |> Enum.filter(fn log -> Enum.member?(topics, log.first_topic) end)
    |> Enum.reduce([], fn log, accounts -> do_parse_signers(log, accounts) end)
  end

  def get_wallets(logs) do
    logs
    |> Enum.filter(fn log -> log.first_topic == Events.account_wallet_address_set_event() end)
    |> Enum.reduce([], fn log, wallets -> do_parse_wallets(log, wallets) end)
  end

  def get_voters(logs, topics) do
    logs
    |> Enum.filter(fn log -> Enum.member?(topics, log.first_topic) end)
    |> Enum.reduce([], fn log, accounts -> do_parse_voters(log, accounts) end)
  end

  defp do_parse(log, accounts, get_topic) do
    account_address_hash = parse_params(log, get_topic)
    entry = %{address_hash: account_address_hash, block_number: log.block_number}

    if Enum.any?(accounts, &(&1.address_hash == account_address_hash)) do
      accounts
    else
      [entry | accounts]
    end
  rescue
    _ in [FunctionClauseError, MatchError] ->
      Logger.error(fn -> "Unknown account event format: #{inspect(log)}" end)
      accounts
  end

  defp do_parse_signers(log, accounts) do
    signer_pair = parse_signer_params(log)
    [signer_pair | accounts]
  rescue
    _ in [FunctionClauseError, MatchError] ->
      Logger.error(fn -> "Unknown signer authorization event format: #{inspect(log)}" end)
      accounts
  end

  defp do_parse_wallets(log, wallets) do
    wallet = parse_wallet_params(log)
    [wallet | wallets]
  rescue
    _ in [FunctionClauseError, MatchError] ->
      Logger.error(fn -> "Unknown account wallet address set event format: #{inspect(log)}" end)
      wallets
  end

  defp do_parse_voters(log, accounts) do
    pair = parse_voter_params(log)
    [pair | accounts]
  rescue
    _ in [FunctionClauseError, MatchError] ->
      Logger.error(fn -> "Unknown voting event format: #{inspect(log)}" end)
      accounts
  end

  defp do_parse_name(log, names) do
    [name] = decode_data(log.data, [:string])

    entry = %{
      name: String.slice(name, 0, @max_name_length),
      address_hash: truncate_address_hash(log.second_topic),
      primary: true
    }

    [entry | names]
  rescue
    _ in [FunctionClauseError, MatchError] ->
      Logger.error(fn -> "Unknown account name event format: #{inspect(log)}" end)
      names
  end

  defp do_parse_withdrawal_events(log, accounts, get_topic) do
    account_address = parse_params(log, get_topic)

    # GoldUnlocked has 2 unindexed parameters which end up in the data field, while the rest of the withdrawal events
    # only 1. Each of these parameters are of length 64 plus 2 for the 0x.
    if String.length(log.data) > 66 do
      [amount, available] = decode_data(log.data, [{:uint, 256}, {:uint, 256}])
      %{address: account_address, amount: amount, available: available}
    else
      [amount] = decode_data(log.data, [{:uint, 256}])
      %{address: account_address, amount: amount}
    end
  rescue
    _ in [FunctionClauseError, MatchError] ->
      Logger.error(fn -> "Unknown account event format: #{inspect(log)}" end)
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

  defp parse_wallet_params(log) do
    account = truncate_address_hash(log.second_topic)
    wallet = truncate_address_hash(log.data)

    %{
      account_address_hash: account,
      wallet_address_hash: wallet,
      block_number: log.block_number
    }
  end

  defp parse_voter_params(log) do
    voter_address = truncate_address_hash(log.second_topic)
    group_address = truncate_address_hash(log.third_topic)
    %{group_address: group_address, voter_address: voter_address}
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
