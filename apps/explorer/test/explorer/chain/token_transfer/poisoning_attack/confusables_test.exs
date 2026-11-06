# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.ConfusablesTest do
  use ExUnit.Case, async: true

  alias Explorer.Chain.TokenTransfer.PoisoningAttack.Confusables

  doctest Confusables, import: true

  describe "skeleton/1" do
    test "folds Cyrillic look-alikes, uppercase ones once lowercased" do
      # Cyrillic а, lowercase of Cyrillic Е, Cyrillic ѕ
      assert Confusables.skeleton("аеѕ") == "aes"
      assert Confusables.skeleton(String.downcase("UЅ" <> "DТ")) == "usdt"
    end

    test "folds Greek, Cherokee and Canadian syllabics look-alikes" do
      # Greek Τ, Greek Ϲ
      assert Confusables.skeleton(String.downcase("ΤϹ")) == "tc"
      # Cherokee Ꭺ, Ꮲ, Ꭼ
      assert Confusables.skeleton(String.downcase("ᎪᏢᎬ")) == "ape"
      # syllabics ᗅ, ᑕ, ᑭ
      assert Confusables.skeleton("ᗅᑕᑭ") == "acp"
    end

    test "leaves everything else alone" do
      # Cyrillic ж and Greek ω resemble no Latin letter
      assert Confusables.skeleton("usdt жω 42") == "usdt жω 42"
      assert Confusables.skeleton("") == ""
    end
  end
end
