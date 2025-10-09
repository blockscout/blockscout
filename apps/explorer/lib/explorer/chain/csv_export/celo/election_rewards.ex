defmodule Explorer.Chain.CsvExport.Address.Celo.ElectionRewards do
  @moduledoc """
  Exports Celo election rewards to a csv file.
  """
  alias Explorer.Chain.Celo.{ElectionReward, Epoch}
  alias Explorer.Chain.CsvExport.Helper
  alias Explorer.Chain.{Hash, Wei}

  @spec export(Hash.Address.t(), String.t() | nil, String.t() | nil, Keyword.t(), any(), any()) :: Enumerable.t()
  def export(address_hash, from_period, to_period, _options, _filter_type, _filter_value) do
    {from_block, to_block} = Helper.block_from_period(from_period, to_period)
    epoch_range = Epoch.block_range_to_epoch_range(from_block, to_block)

    options = [
      necessity_by_association: %{
        :account_address => :optional,
        :associated_account_address => :optional,
        [epoch: [:end_processing_block]] => :optional
      },
      paging_options: Helper.paging_options(),
      api?: true
    ]

    epoch_range
    |> case do
      nil ->
        []

      {from_epoch, to_epoch} ->
        full_options =
          options
          |> Keyword.put(:from_epoch, from_epoch)
          |> Keyword.put(:to_epoch, to_epoch)

        address_hash |> ElectionReward.address_hash_to_rewards(full_options)
    end
    |> to_csv_format()
    |> Helper.dump_to_stream()
  end

  @spec to_csv_format(Enumerable.t()) :: Enumerable.t()
  defp to_csv_format(election_rewards) do
    column_names = [
      "EpochNumber",
      "BlockNumber",
      "TimestampUTC",
      "EpochTxType",
      "ValidatorAddress",
      "ValidatorGroupAddress",
      "ToAddress",
      "Type",
      "Value",
      "ValueInWei",
      "TokenSymbol",
      "TokenContractAddress"
    ]

    reward_type_to_human_readable = %{
      voter: "Voter Rewards",
      validator: "Validator Rewards",
      group: "Validator Group Rewards",
      delegated_payment: "Delegated Validator Rewards"
    }

    rows =
      election_rewards
      |> Stream.map(fn reward ->
        block = reward.epoch.end_processing_block

        [
          # EpochNumber
          reward.epoch_number,
          # BlockNumber
          block.number,
          # TimestampUTC
          block.timestamp,
          # EpochTxType
          Map.get(reward_type_to_human_readable, reward.type, "N/A"),
          # ValidatorAddress
          (reward.type in ~w(group delegated_payment)a && reward.associated_account_address_hash) || "N/A",
          # ValidatorGroupAddress
          (reward.type in ~w(validator voter)a && reward.associated_account_address_hash) || "N/A",
          # ToAddress
          reward.account_address_hash,
          # Type
          "IN",
          # Value
          reward.amount |> Wei.to(:ether) |> Decimal.to_string(:normal),
          # ValueInWei
          reward.amount |> Wei.to(:wei) |> Decimal.to_string(:normal),
          # TokenSymbol
          reward.token.symbol,
          # TokenContractAddress
          reward.token.contract_address_hash
        ]
      end)

    Stream.concat([column_names], rows)
  end
end
