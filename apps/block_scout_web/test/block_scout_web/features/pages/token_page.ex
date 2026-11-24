# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.TokenPage do
  @moduledoc false

  use Fluffy.Assert

  import Fluffy
  import Fluffy.Locator
  alias Explorer.Chain.{Address}

  def visit_page(session, %Address{hash: address_hash}) do
    visit_page(session, address_hash)
  end

  def visit_page(session, contract_address_hash) do
    visit(session, "/tokens/#{contract_address_hash}/token-holders")
  end

  def token_holders_tab(count: count) do
    count(filter(by_test_id("token_holders_tab"), visible: true), count)
  end

  def click_tokens_holders(session) do
    click(session, by_test_id("token_holders_tab"))
  end

  def token_holders(count: count) do
    count(filter(by_test_id("token_holders"), visible: true), count)
  end
end
