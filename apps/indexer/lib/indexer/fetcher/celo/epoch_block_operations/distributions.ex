defmodule Indexer.Fetcher.Celo.EpochBlockOperations.Distributions do
  @moduledoc """
  Fetches Reserve bolster, Community, and Carbon offsetting distributions for
  the epoch block.
  """
  import Ecto.Query, only: [from: 2, subquery: 1]
  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  alias Explorer.Repo

  alias Explorer.Chain.{
    Cache.CeloCoreContracts,
    Hash,
    TokenTransfer
  }

  @mint_address_hash_string burn_address_hash_string()

  @spec fetch(%{
          :block_hash => EthereumJSONRPC.hash(),
          :block_number => EthereumJSONRPC.block_number()
        }) ::
          {:ok, map()}
          | {:error, :multiple_transfers_to_same_address}
  def fetch(%{block_number: block_number, block_hash: block_hash} = _pending_operation) do
    {:ok, celo_token_contract_address_hash} = CeloCoreContracts.get_address(:celo_token, block_number)
    {:ok, reserve_contract_address_hash} = CeloCoreContracts.get_address(:reserve, block_number)
    {:ok, community_contract_address_hash} = CeloCoreContracts.get_address(:governance, block_number)

    {:ok, %{"address" => carbon_offsetting_contract_address_hash}} =
      CeloCoreContracts.get_event(:epoch_rewards, :carbon_offsetting_fund_set, block_number)

    celo_mint_transfers_query =
      from(
        tt in TokenTransfer.only_consensus_transfers_query(),
        where:
          tt.block_hash == ^block_hash and
            tt.token_contract_address_hash == ^celo_token_contract_address_hash and
            tt.from_address_hash == ^@mint_address_hash_string and
            is_nil(tt.transaction_hash)
      )

    # Every epoch has at least one CELO transfer from the zero address to the
    # reserve. This is how cUSD is minted before it is distributed to
    # validators. If there is only one CELO transfer, then there was no
    # Reserve bolster distribution for that epoch. If there are multiple CELO
    # transfers, then the last one is the Reserve bolster distribution.
    reserve_bolster_transfer_log_index_query =
      from(
        tt in subquery(
          from(
            tt in subquery(celo_mint_transfers_query),
            where: tt.to_address_hash == ^reserve_contract_address_hash,
            order_by: tt.log_index,
            offset: 1
          )
        ),
        select: max(tt.log_index)
      )

    query =
      from(
        tt in subquery(celo_mint_transfers_query),
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
        |> Map.put(:block_hash, block_hash)

      {:ok, distributions}
    else
      {:error, :multiple_transfers_to_same_address}
    end
  end
end
