# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.ContractVerifyPage do
  @moduledoc false

  use Fluffy.Assert

  import Fluffy
  import Fluffy.Locator

  def visit_page(session, address_hash) do
    visit(session, "/address/#{address_hash}/verify-via-flattened-code/new")
  end

  def fill_form(session, %{
        contract_name: contract_name,
        version: version,
        optimization: optimization,
        source_code: source_code,
        evm_version: evm_version
      }) do
    session
    |> fill(by_test_id("contract_name"), contract_name)
    |> fill(by_label("Enter the Solidity Contract Code"), source_code)

    case version do
      # Leave the compiler's default selection in place; "default" is only an EVM option.
      version when version in [nil, "default"] -> nil
      _ -> select_option(session, by_label("Compiler", exact: true), %{label: version})
    end

    case evm_version do
      nil -> nil
      _ -> select_option(session, by_label("EVM Version", exact: true), %{label: evm_version})
    end

    case optimization do
      true ->
        check(session, by_label("Yes", exact: true))

      false ->
        check(session, by_label("No", exact: true))

      _ ->
        nil
    end

    session
  end

  def validation_error do
    by_test_id("contract-source-code-error")
  end

  def verify_and_publish(session) do
    click(session, by_role(:button, name: "Verify & publish"))
  end
end
