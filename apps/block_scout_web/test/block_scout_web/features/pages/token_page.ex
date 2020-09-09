defmodule BlockScoutWeb.TokenPage do
  @moduledoc false

  use Wallaby.DSL
  import Wallaby.Query, only: [css: 1, css: 2]
  alias Explorer.Chain.{Address}

  def visit_page(session, %Address{hash: address_hash}) do
    visit_page(session, address_hash)
  end

  def visit_page(session, contract_address_hash) do
    visit(session, "tokens/#{contract_address_hash}/token-holders")
  end

  def token_holders_tab(count: count) do
    css("[data-test='token_holders_tab']", count: count)
  end

  def click_tokens_holders(session) do
    click(session, css("[data-test='token_holders_tab']"))
  end

  def token_holders(count: count) do
    css("[data-test='token_holders']", count: count)
  end
end
