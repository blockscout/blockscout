defmodule Indexer.Transform.Celo.Epoch.PaymentDelegationTransfers do
  @moduledoc """
  Extracts the payment delegation transfers.
  """

  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Explorer.Chain.TokenTransfer
  alias Explorer.Helper

  def parse(logs) do
    usd_token_contract_address = CeloCoreContracts.get_address(:usd_token)

    logs
    |> Enum.filter(
      &(&1.address_hash == usd_token_contract_address and
          &1.first_topic == TokenTransfer.constant() and
          &1.second_topic == "0x0000000000000000000000000000000000000000000000000000000000000000")
    )
    |> Enum.map(fn %{third_topic: third_topic, data: data} ->
      [amount] = Helper.decode_data(data, [{:uint, 256}])
      [beneficiary_address] = Helper.decode_data(third_topic, [:address])

      {
        "0x" <> Base.encode16(beneficiary_address, case: :lower),
        Decimal.new(amount || 0)
      }
    end)
    |> Map.new()
  end
end
