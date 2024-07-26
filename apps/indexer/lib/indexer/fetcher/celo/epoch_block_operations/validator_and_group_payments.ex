defmodule Indexer.Fetcher.Celo.EpochBlockOperations.ValidatorAndGroupPayments do
  @moduledoc """
  Fetches validator and group payments for the epoch block.
  """
  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Explorer.Chain.Log
  alias Explorer.Repo
  alias Indexer.Transform.Celo.ValidatorEpochPaymentDistributions

  @spec fetch(%{
          :block_hash => EthereumJSONRPC.hash(),
          :block_number => EthereumJSONRPC.block_number()
        }) :: {:ok, list()}
  def fetch(%{block_number: block_number, block_hash: block_hash} = _pending_operation) do
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
      |> process_distribution_events(block_hash)

    {:ok, payments}
  end

  defp process_distribution_events(distribution_events, block_hash) do
    distribution_events
    |> Enum.map(fn %{
                     validator_address: validator_address,
                     validator_payment: validator_payment,
                     group_address: group_address,
                     group_payment: group_payment
                   } ->
      [
        %{
          block_hash: block_hash,
          account_address_hash: validator_address,
          amount: validator_payment,
          associated_account_address_hash: group_address,
          type: :validator
        },
        %{
          block_hash: block_hash,
          account_address_hash: group_address,
          amount: group_payment,
          associated_account_address_hash: validator_address,
          type: :group
        }
      ]
    end)
    |> Enum.concat()
  end
end
