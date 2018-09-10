defmodule BlockScoutWeb.AddressContractPage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 1]

  def on_page?(session, address) do
    current_path(session) =~ address_contract_path(address)
  end

  def click_verify_and_publish(session) do
    click(session, css("[data-test='verify_and_publish']"))
  end

  def visit_page(session, address) do
    visit(session, address_contract_path(address))
  end

  defp address_contract_path(address) do
    "/address/#{address.hash}/contracts"
  end
end
