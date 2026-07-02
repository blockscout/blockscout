# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.Celo.EpochBlockOperations.ValidatorAndGroupPaymentsPriorL2Migration do
  @moduledoc """
  Fetches validator and group payments for the epoch block.
  """
  import Ecto.Query

  alias Explorer.Chain.{Block, Celo.Epoch, Log}
  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Explorer.Repo
  alias Explorer.Utility.LogHelper
  alias Indexer.Transform.Celo.ValidatorEpochPaymentDistributions

  @spec fetch(Epoch.t()) :: {:ok, list()}
  def fetch(%Epoch{start_processing_block: %Block{number: block_number}} = epoch) do
    epoch_payment_distributions_signature = ValidatorEpochPaymentDistributions.signature()
    {:ok, validators_contract_address} = CeloCoreContracts.get_address(:validators, block_number)

    query =
      Log
      |> Log.address_match_query(validators_contract_address)
      |> where([log], log.block_number == ^block_number)
      |> where([log], log.first_topic == ^epoch_payment_distributions_signature)
      |> then(fn query ->
        cond do
          LogHelper.fill_transaction_index_address_id_migration_finished?() ->
            where(query, [log], is_nil(log.transaction_index))

          LogHelper.fill_transaction_index_address_id_migration_started?() ->
            where(query, [log], is_nil(log.transaction_hash) and is_nil(log.transaction_index))

          true ->
            where(query, [log], is_nil(log.transaction_hash))
        end
      end)

    payments =
      query
      |> Repo.all()
      |> ValidatorEpochPaymentDistributions.parse()
      |> Enum.flat_map(fn %{
                            validator_address: validator_address,
                            validator_payment: validator_payment,
                            group_address: group_address,
                            group_payment: group_payment
                          } ->
        [
          %{
            epoch_number: epoch.number,
            account_address_hash: validator_address,
            amount: validator_payment,
            associated_account_address_hash: group_address,
            type: :validator
          },
          %{
            epoch_number: epoch.number,
            account_address_hash: group_address,
            amount: group_payment,
            associated_account_address_hash: validator_address,
            type: :group
          }
        ]
      end)

    {:ok, payments}
  end
end
