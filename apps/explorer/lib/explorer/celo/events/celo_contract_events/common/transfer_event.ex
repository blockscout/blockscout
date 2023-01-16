defmodule Explorer.Celo.ContractEvents.Common.TransferEvent do
  @moduledoc """
  Struct modelling the Transfer event from the Stabletoken, Goldtoken, Erc20, Stabletokenbrl, Stabletokeneur Celo core contracts.
  """

  alias Explorer.Celo.ContractEvents.EventMap
  alias Explorer.Repo

  use Explorer.Celo.ContractEvents.Base,
    name: "Transfer",
    topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

  event_param(:from, :address, :indexed)
  event_param(:to, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)

  def payment_delegation_transfers_for(beneficiary_hash, block_number) do
    query =
      from(
        cce in Explorer.Chain.CeloContractEvent,
        join: ccc in Explorer.Chain.CeloCoreContract,
        on: ccc.address_hash == cce.contract_address_hash,
        where: ccc.name == "StableToken",
        where: cce.topic == ^@topic,
        where: cce.block_number == ^block_number,
        where: fragment("?->>'from' = '\\x0000000000000000000000000000000000000000'", cce.params),
        where: fragment("cast(?->>'to' AS bytea) = ?", cce.params, ^beneficiary_hash.bytes)
      )

    raw_transfer_event = query |> Repo.one()

    case raw_transfer_event do
      nil -> nil
      transfer_event -> EventMap.celo_contract_event_to_concrete_event(transfer_event)
    end
  end
end
