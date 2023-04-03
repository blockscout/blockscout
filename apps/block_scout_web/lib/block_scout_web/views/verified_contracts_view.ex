defmodule BlockScoutWeb.VerifiedContractsView do
  use BlockScoutWeb, :view

  alias Explorer.Celo.CoreContracts
  alias Explorer.Chain.{Address, SmartContract, Wei}

  import BlockScoutWeb.GenericPaginationHelpers
  import BlockScoutWeb.AddressView, only: [balance: 1]
  alias BlockScoutWeb.WebRouter.Helpers

  def detect_license(contract) do
    cond do
      license = spdx_tag(contract.contract_source_code) ->
        license

      CoreContracts.is_core_contract_address?(contract.address.hash) ->
        "LGPL-3.0"

      true ->
        "Unknown"
    end
  end

  def spdx_tag(source) do
    ~r/SPDX-License-Identifier:\s+(.*)/
    |> Regex.run(source, capture: :all_but_first)
  end

  def contract_balance(%SmartContract{address: %Address{fetched_coin_balance: balance}}) when not is_nil(balance) do
    balance
    |> Wei.to(:ether)
    |> Decimal.round(3)
  end

  def contract_balance(_contract) do
    0
  end

  def format_current_filter(filter) do
    case filter do
      "solidity" -> gettext("Solidity")
      "vyper" -> gettext("Vyper")
      _ -> gettext("All")
    end
  end
end
