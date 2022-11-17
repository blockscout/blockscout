defmodule Explorer.Export.CSV.EpochTransactionExporter do
  @moduledoc "Export all Epoch Transactions for given address"

  import Ecto.Query

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.Celo.EpochUtil
  alias Explorer.Chain
  alias Explorer.Chain.{Address, CeloAccountEpoch, CeloElectionRewards, Wei}

  @behaviour Explorer.Export.CSV.Exporter

  @preloads []

  @row_header [
    "Epoch",
    "BlockNumber",
    "TimestampUTC",
    "EpochTxType",
    "FromAddress",
    "ToAddress",
    "Type",
    "LockedGold",
    "ActivatedGold",
    "Value",
    "ValueInWei",
    "TokenSymbol",
    "TokenContractAddress"
  ]

  @impl true
  def query(%Address{hash: address_hash}, from, to) do
    from_block = Chain.convert_date_to_min_block(from)
    to_block = Chain.convert_date_to_max_block(to)

    query =
      from(rewards in CeloElectionRewards,
        left_join: celo_account_epoch in CeloAccountEpoch,
        on:
          rewards.account_hash == celo_account_epoch.account_hash and
            celo_account_epoch.block_number == rewards.block_number,
        select: %{
          epoch_number: fragment("? / 17280", rewards.block_number),
          block_number: rewards.block_number,
          timestamp: rewards.block_timestamp,
          epoch_tx_type: rewards.reward_type,
          from_address: rewards.associated_account_hash,
          to_address: rewards.account_hash,
          value_wei: rewards.amount,
          locked_gold: celo_account_epoch.total_locked_gold,
          activated_gold:
            fragment(
              "? - ?",
              celo_account_epoch.total_locked_gold,
              celo_account_epoch.nonvoting_locked_gold
            )
        },
        order_by: [desc: rewards.block_number, asc: rewards.reward_type],
        where: rewards.account_hash == ^address_hash,
        where: rewards.amount > ^%Wei{value: Decimal.new(0)}
      )

    query |> Chain.where_block_number_in_period(from_block, to_block)
  end

  @impl true
  def associations, do: @preloads

  @impl true
  def row_names, do: @row_header

  @impl true
  def transform(epoch_transaction, _address) do
    [
      #      "Epoch",
      epoch_transaction.epoch_number,
      #      "BlockNumber",
      epoch_transaction.block_number,
      #      "TimestampUTC",
      to_string(epoch_transaction.timestamp),
      #      "EpochTxType",
      epoch_transaction.epoch_tx_type |> reward_type_to_human_readable,
      #      "FromAddress",
      to_string(epoch_transaction.from_address),
      #      "ToAddress",
      to_string(epoch_transaction.to_address),
      #      "Type",
      "IN",
      #      "LockedGold",
      epoch_transaction.locked_gold |> locked_or_activated_gold_when_applicable(epoch_transaction.epoch_tx_type),
      #      "ActivatedGold",
      epoch_transaction.activated_gold |> locked_or_activated_gold_when_applicable(epoch_transaction.epoch_tx_type),
      #      "Value",
      epoch_transaction.value_wei |> Wei.to(:ether),
      #      "ValueInWei",
      epoch_transaction.value_wei |> Wei.to(:wei),
      #      "TokenSymbol",
      epoch_transaction.epoch_tx_type |> token_symbol(),
      #      "TokenContractAddress",
      epoch_transaction.epoch_tx_type |> EpochUtil.get_reward_currency_address_hash()
    ]
  end

  # Unlikely case when there's no locked/activated gold data for a particular account
  defp locked_or_activated_gold_when_applicable(nil = _value, "voter"), do: "unknown"
  defp locked_or_activated_gold_when_applicable(%Wei{} = value, "voter"), do: value |> Wei.to(:ether)
  defp locked_or_activated_gold_when_applicable(%Decimal{} = value, "voter"), do: %Wei{value: value} |> Wei.to(:ether)

  defp locked_or_activated_gold_when_applicable(_value, reward_type) when reward_type in ["validator", "group"],
    do: "N/A"

  defp reward_type_to_human_readable("voter"), do: "Voter Rewards"
  defp reward_type_to_human_readable("validator"), do: "Validator Rewards"
  defp reward_type_to_human_readable("group"), do: "Validator Group Rewards"

  defp token_symbol("voter"), do: "CELO"
  defp token_symbol(type) when type in ["validator", "group"], do: "cUSD"
end
