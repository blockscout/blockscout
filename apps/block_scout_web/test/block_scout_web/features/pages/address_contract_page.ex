# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.AddressContractPage do
  @moduledoc false

  use Fluffy.Assert

  import Fluffy
  import Fluffy.Locator

  def on_page?(session, address) do
    Fluffy.Playwright.evaluate(session, "() => location.pathname") =~ address_contract_path(address)
  end

  def click_verify_and_publish(session) do
    click(session, by_css("[data-test='verify_and_publish']"))
  end

  def visit_page(session, address) do
    visit(session, address_contract_path(address))
  end

  defp address_contract_path(address) do
    "/address/#{address.hash}/contracts"
  end
end
