defmodule Indexer.Transform.Celo.Epoch.ReservedBolsterTransferAmount do
  @moduledoc """
  Extracts the amount transfered to `Reserve`.
  """

  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Explorer.Chain.TokenTransfer
  alias Explorer.Helper

  def parse(logs) do
    from_address_topic = "0x0000000000000000000000000000000000000000000000000000000000000000"
    transfer_event_signature = TokenTransfer.constant()
    celo_token_contract_address = CeloCoreContracts.get_address(:celo_token)

    reserve_contract_address_topic =
      :reserve
      |> CeloCoreContracts.get_address()
      |> String.replace_leading("0x", "0x000000000000000000000000")

    logs
    |> Enum.filter(
      &match?(
        %{
          address_hash: ^celo_token_contract_address,
          first_topic: ^transfer_event_signature,
          second_topic: ^from_address_topic,
          third_topic: ^reserve_contract_address_topic
        },
        &1
      )
    )
    |> case do
      [%{data: data}] ->
        [amount] = Helper.decode_data(data, [{:uint, 256}])
        Decimal.new(amount || 0)

      [] ->
        0
    end
  end
end
