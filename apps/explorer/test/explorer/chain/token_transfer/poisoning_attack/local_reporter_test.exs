# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.LocalReporterTest do
  use Explorer.DataCase

  import Ecto.Query, only: [from: 2]
  import Explorer.Factory

  alias Explorer.Chain.Address.ScamBadgeToAddress
  alias Explorer.Chain.TokenTransfer.PoisoningAttack.{LocalReporter, Result}
  alias Explorer.Repo
  alias Explorer.Tags.{AddressTag, AddressToTag}

  @moduletag :capture_log

  defp result(victim, mimic, issuer, rules \\ [:lookalike_recipient, :suspicious_outgoing]) do
    %Result{
      score: 7,
      rules: rules,
      victim: victim,
      mimic: mimic,
      issuer: issuer
    }
  end

  defp scam_badges do
    ScamBadgeToAddress |> Repo.all() |> Enum.map(& &1.address_hash) |> MapSet.new()
  end

  defp phishing_tagged do
    from(att in AddressToTag,
      join: tag in AddressTag,
      on: tag.id == att.tag_id,
      where: tag.label == ^LocalReporter.phishing_tag_label(),
      select: att.address_hash
    )
    |> Repo.all()
    |> MapSet.new()
  end

  describe "report/1" do
    test "gives the issuer the scam badge and the mimic the phishing tag" do
      victim = insert(:address)
      mimic = insert(:address)
      issuer = insert(:address)

      assert :ok = LocalReporter.report([result(victim.hash, mimic.hash, issuer.hash)])

      assert scam_badges() == MapSet.new([issuer.hash])
      assert phishing_tagged() == MapSet.new([mimic.hash])
      assert %AddressTag{display_name: "Phishing"} = Repo.get_by(AddressTag, label: "phishing")
    end

    test "never marks the victim" do
      victim = insert(:address)
      other = insert(:address)

      assert :ok =
               LocalReporter.report([
                 result(victim.hash, victim.hash, other.hash),
                 result(victim.hash, other.hash, victim.hash)
               ])

      assert scam_badges() == MapSet.new([other.hash])
      assert phishing_tagged() == MapSet.new([other.hash])
    end

    test "marks an issuer that is also the mimic with both" do
      victim = insert(:address)
      attacker = insert(:address)

      assert :ok = LocalReporter.report([result(victim.hash, attacker.hash, attacker.hash)])

      assert scam_badges() == MapSet.new([attacker.hash])
      assert phishing_tagged() == MapSet.new([attacker.hash])
    end

    test "leaves the counterparty untagged when no look-alike was matched" do
      victim = insert(:address)
      airdrop_recipient = insert(:address)
      issuer = insert(:address)

      # a badged issuer airdropping a fake asset: the recipient is a target, not a mimic
      assert :ok =
               LocalReporter.report([
                 result(victim.hash, airdrop_recipient.hash, issuer.hash, [
                   :scam_flag,
                   :name_imitation,
                   :suspicious_outgoing
                 ])
               ])

      assert scam_badges() == MapSet.new([issuer.hash])
      assert phishing_tagged() == MapSet.new()
      refute Repo.get_by(AddressTag, label: "phishing")
    end

    test "tags a counterparty that sent the transaction itself whatever the rules" do
      victim = insert(:address)
      duster = insert(:address)

      assert :ok =
               LocalReporter.report([
                 result(victim.hash, duster.hash, duster.hash, [:scam_flag, :dust_from_counterparty])
               ])

      assert scam_badges() == MapSet.new([duster.hash])
      assert phishing_tagged() == MapSet.new([duster.hash])
    end

    test "copes without an issuer" do
      victim = insert(:address)
      mimic = insert(:address)

      assert :ok = LocalReporter.report([result(victim.hash, mimic.hash, nil)])

      assert scam_badges() == MapSet.new()
      assert phishing_tagged() == MapSet.new([mimic.hash])
    end

    test "is idempotent and reuses the existing tag" do
      victim = insert(:address)
      mimic = insert(:address)
      issuer = insert(:address)
      insert(:address_tag, label: "phishing", display_name: "Phishing")

      assert :ok = LocalReporter.report([result(victim.hash, mimic.hash, issuer.hash)])
      assert :ok = LocalReporter.report([result(victim.hash, mimic.hash, issuer.hash)])

      assert Repo.aggregate(ScamBadgeToAddress, :count) == 1
      assert Repo.aggregate(AddressToTag, :count) == 1
      assert Repo.aggregate(AddressTag, :count) == 1
    end

    test "does nothing for no attacks" do
      assert :ok = LocalReporter.report([])
      assert Repo.aggregate(AddressTag, :count) == 0
    end
  end
end
