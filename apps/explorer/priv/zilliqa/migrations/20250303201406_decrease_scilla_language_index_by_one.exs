defmodule Explorer.Repo.Zilliqa.Migrations.DecreaseScillaLanguageIndexByOne do
  @moduledoc """
  Migration to update the language identifier for Scilla smart contracts in Zilliqa.

  ## Background

  This migration adjusts the language enumeration used for Zilliqa smart contracts.

  Previously, the language enum for smart contracts included:
  - 1: solidity
  - 2: vyper
  - 3: yul
  - 4: stylus_rust
  - 5: scilla

  ## Changes

  As part of chain-specific language enumeration refinement:
  - `stylus_rust` is now exclusively under the Arbitrum chain type
  - For Zilliqa, we now have: 1: solidity, 2: vyper, 3: yul, 4: scilla

  This migration updates all Scilla smart contracts (previously with language=5)
  to use the new language identifier (4), accounting for the removal of stylus_rust
  from the Zilliqa chain type language enumeration.
  """
  use Ecto.Migration

  def change do
    execute(
      # Up - change language from 5 to 4
      "UPDATE smart_contracts SET language = 4 WHERE language = 5",
      # Down - change language from 3 back to 4
      "UPDATE smart_contracts SET language = 5 WHERE language = 4"
    )
  end
end
