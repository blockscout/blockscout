defmodule Explorer.Celo.RebuildAttestationStatsTest do
  use Explorer.DataCase
  use Explorer.Celo.EventTypes

  alias __MODULE__
  alias Explorer.Celo.RebuildAttestationStats
  alias Explorer.Chain.CeloAccount

  def address_topic(%CeloAccount{address: address}) do
    address
    |> Explorer.Chain.Hash.to_string()
    |> address_topic
  end

  def address_topic("0x" <> rest), do: "0x000000000000000000000000" <> rest

  def insert_attestation_selected_log(account) do
    insert(:log,
      first_topic: @attestation_issuer_selected,
      fourth_topic: address_topic(account)
    )

    account
  end

  def insert_attestation_completed_log(account) do
    insert(:log,
      first_topic: @attestation_completed,
      fourth_topic: address_topic(account)
    )

    account
  end

  describe "rebuild_attestation_stats/1" do
    setup do
      [account: insert(:celo_account)]
    end

    test "updates attestation stats for a given account", %{account: account} do
      assert account.attestations_requested == nil
      assert account.attestations_fulfilled == nil

      account
      |> insert_attestation_selected_log()
      |> insert_attestation_selected_log()
      |> insert_attestation_selected_log()
      |> insert_attestation_completed_log()

      RebuildAttestationStats.rebuild_attestation_stats(15)

      with updated <- CeloAccount |> Repo.get(account.id) do
        assert updated.attestations_requested == 3
        assert updated.attestations_fulfilled == 1
      end
    end

    test "don't touch unrelated accounts", %{account: account} do
      account2 = insert(:celo_account)

      assert account2.attestations_requested == nil
      assert account2.attestations_fulfilled == nil

      account
      |> insert_attestation_selected_log()
      |> insert_attestation_selected_log()
      |> insert_attestation_completed_log()

      RebuildAttestationStats.rebuild_attestation_stats(15)

      with updated <- CeloAccount |> Repo.get(account.id),
           updated2 <- CeloAccount |> Repo.get(account2.id) do
        assert updated.attestations_requested == 2
        assert updated.attestations_fulfilled == 1
        assert updated2.attestations_requested == nil
        assert updated2.attestations_fulfilled == nil
      end
    end
  end
end
