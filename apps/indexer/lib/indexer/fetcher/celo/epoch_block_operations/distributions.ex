defmodule Indexer.Fetcher.Celo.EpochBlockOperations.Distributions do
  @moduledoc """
  Fetches Reserve bolster, Community, and Carbon offsetting distributions for
  the epoch block.
  """
  use Utils.RuntimeEnvHelper,
    celo_unreleased_treasury_contract_address: [
      :explorer,
      [:celo, :celo_unreleased_treasury_contract_address]
    ]

  import Ecto.Query, only: [from: 2, subquery: 1]
  import Explorer.Chain.Celo.Helper, only: [pre_migration_block_number?: 1]
  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  alias Explorer.Chain.{
    Block,
    Cache.CeloCoreContracts,
    Hash,
    TokenTransfer
  }

  alias Explorer.Chain.Celo.Epoch
  alias Explorer.Repo

  @spec fetch(Epoch.t()) ::
          {:ok, map()}
          | {:error, :multiple_transfers_to_same_address}
  def fetch(%{end_processing_block: %Block{number: block_number, hash: block_hash}} = epoch) do
    {:ok, reserve_contract_address_hash} = CeloCoreContracts.get_address(:reserve, block_number)
    {:ok, community_contract_address_hash} = CeloCoreContracts.get_address(:governance, block_number)

    {:ok, %{"address" => carbon_offsetting_contract_address_hash}} =
      CeloCoreContracts.get_event(:epoch_rewards, :carbon_offsetting_fund_set, block_number)

    celo_distributions_query = celo_distributions_query(block_hash, block_number)

    # Every epoch has at least one CELO transfer from the zero address to the
    # reserve. This is how cUSD is minted before it is distributed to
    # validators. If there is only one CELO transfer, then there was no
    # Reserve bolster distribution for that epoch. If there are multiple CELO
    # transfers, then the last one is the Reserve bolster distribution.
    reserve_bolster_transfer_log_index_query =
      from(
        tt in subquery(
          from(
            tt in subquery(celo_distributions_query),
            where: tt.to_address_hash == ^reserve_contract_address_hash,
            order_by: tt.log_index,
            offset: 1
          )
        ),
        select: max(tt.log_index)
      )

    query =
      from(
        tt in subquery(celo_distributions_query),
        where:
          tt.to_address_hash in ^[
            community_contract_address_hash,
            carbon_offsetting_contract_address_hash
          ] or
            tt.log_index == subquery(reserve_bolster_transfer_log_index_query),
        select: {tt.to_address_hash, tt.log_index}
      )

    transfers_with_log_index = query |> Repo.all()

    unique_addresses_count =
      transfers_with_log_index
      |> Enum.map(&elem(&1, 0))
      |> Enum.uniq()
      |> Enum.count()

    address_to_key = %{
      reserve_contract_address_hash => :reserve_bolster_transfer_log_index,
      community_contract_address_hash => :community_transfer_log_index,
      carbon_offsetting_contract_address_hash => :carbon_offsetting_transfer_log_index
    }

    if unique_addresses_count == Enum.count(transfers_with_log_index) do
      distributions =
        transfers_with_log_index
        |> Enum.reduce(%{}, fn {address, log_index}, acc ->
          key = Map.get(address_to_key, address |> Hash.to_string())
          Map.put(acc, key, log_index)
        end)
        |> Map.put(:epoch_number, epoch.number)

      {:ok, distributions}
    else
      {:error, :multiple_transfers_to_same_address}
    end
  end

  defp celo_distributions_query(block_hash, block_number) do
    {:ok, celo_token_contract_address_hash} = CeloCoreContracts.get_address(:celo_token, block_number)

    query =
      from(
        tt in TokenTransfer.only_consensus_transfers_query(),
        where:
          tt.block_hash == ^block_hash and
            tt.token_contract_address_hash == ^celo_token_contract_address_hash
      )

    if pre_migration_block_number?(block_number) do
      celo_sender_address_hash = burn_address_hash_string()

      from(tt in query, where: tt.from_address_hash == ^celo_sender_address_hash and is_nil(tt.transaction_hash))
    else
      celo_sender_address_hash = celo_unreleased_treasury_contract_address()

      from(tt in query, where: tt.from_address_hash == ^celo_sender_address_hash)
    end
  end
end
