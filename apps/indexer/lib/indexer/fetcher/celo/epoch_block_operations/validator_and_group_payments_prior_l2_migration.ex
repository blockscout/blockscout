defmodule Indexer.Fetcher.Celo.EpochBlockOperations.ValidatorAndGroupPaymentsPriorL2Migration do
  @moduledoc """
  Fetches validator and group payments for the epoch block.
  """
  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Explorer.Chain.{Block, Celo.Epoch, Log}
  alias Explorer.Repo
  alias Indexer.Transform.Celo.ValidatorEpochPaymentDistributions

  @spec fetch(Epoch.t()) :: {:ok, list()}
  def fetch(%Epoch{start_processing_block: %Block{number: block_number, hash: block_hash}} = epoch) do
    epoch_payment_distributions_signature = ValidatorEpochPaymentDistributions.signature()
    {:ok, validators_contract_address} = CeloCoreContracts.get_address(:validators, block_number)

    query =
      from(
        log in Log,
        where:
          log.block_hash == ^block_hash and
            log.address_hash == ^validators_contract_address and
            log.first_topic == ^epoch_payment_distributions_signature and
            is_nil(log.transaction_hash),
        select: log
      )

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
