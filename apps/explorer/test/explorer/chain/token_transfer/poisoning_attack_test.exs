# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttackTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Chain.TokenTransfer.PoisoningAttack
  alias Explorer.Repo
  alias Explorer.Utility.AddressIdToAddressHash

  defp insert_token_transfer do
    insert(:token_transfer, transaction: :transaction |> insert() |> with_block())
  end

  defp attack_params(token_transfer, overrides \\ %{}) do
    Map.merge(
      %{
        block_hash: token_transfer.block_hash,
        log_index: token_transfer.log_index,
        transaction_hash: token_transfer.transaction_hash,
        block_number: token_transfer.block_number,
        token_contract_address_hash: token_transfer.token_contract_address_hash,
        victim_address_hash: token_transfer.from_address_hash,
        mimic_address_hash: token_transfer.to_address_hash,
        issuer_address_hash: address_hash(),
        score: 7,
        rules: ["suspicious_outgoing", "lookalike_recipient"],
        details: %{"lookalike_recipient" => %{"prefix" => "ab12"}}
      },
      overrides
    )
  end

  describe "insert_all/1" do
    test "does nothing for an empty list" do
      assert {0, nil} = PoisoningAttack.insert_all([])
      assert Repo.aggregate(PoisoningAttack, :count) == 0
    end

    test "records attacks and fills the timestamps" do
      token_transfer = insert_token_transfer()

      params = attack_params(token_transfer)

      assert {1, nil} = PoisoningAttack.insert_all([params])

      assert [%PoisoningAttack{} = attack] = PoisoningAttack |> PoisoningAttack.with_address_hashes() |> Repo.all()
      assert attack.block_hash == token_transfer.block_hash
      assert attack.log_index == token_transfer.log_index
      assert attack.transaction_hash == token_transfer.transaction_hash
      assert attack.token_contract_address_hash == token_transfer.token_contract_address_hash
      assert attack.victim_address_hash == token_transfer.from_address_hash
      assert attack.mimic_address_hash == token_transfer.to_address_hash
      assert attack.issuer_address_hash == params.issuer_address_hash
      assert attack.score == 7
      assert attack.rules == ["suspicious_outgoing", "lookalike_recipient"]
      assert attack.details == %{"lookalike_recipient" => %{"prefix" => "ab12"}}
      assert attack.inserted_at
      assert attack.updated_at
    end

    test "defaults details to an empty map and accepts a missing issuer" do
      token_transfer = insert_token_transfer()

      params =
        token_transfer
        |> attack_params()
        |> Map.delete(:details)
        |> Map.put(:issuer_address_hash, nil)

      assert {1, nil} = PoisoningAttack.insert_all([params])

      assert [%PoisoningAttack{details: %{}, issuer_address_id: nil, issuer_address_hash: nil}] =
               PoisoningAttack |> PoisoningAttack.with_address_hashes() |> Repo.all()
    end

    test "stores the participants by address id, creating missing mappings" do
      token_transfer = insert_token_transfer()
      issuer_hash = address_hash()
      assert AddressIdToAddressHash.hash_to_id(issuer_hash) == nil

      assert {1, nil} = PoisoningAttack.insert_all([attack_params(token_transfer, %{issuer_address_hash: issuer_hash})])

      assert [%PoisoningAttack{} = attack] = Repo.all(PoisoningAttack)
      assert attack.victim_address_id == AddressIdToAddressHash.hash_to_id(token_transfer.from_address_hash)
      assert attack.mimic_address_id == AddressIdToAddressHash.hash_to_id(token_transfer.to_address_hash)

      assert attack.token_contract_address_id ==
               AddressIdToAddressHash.hash_to_id(token_transfer.token_contract_address_hash)

      assert attack.issuer_address_id == AddressIdToAddressHash.hash_to_id(issuer_hash)
      assert is_integer(attack.issuer_address_id)
      # the hashes are not stored, only joined on read
      assert attack.victim_address_hash == nil
    end

    test "overwrites the row of a transfer recorded earlier" do
      token_transfer = insert_token_transfer()

      assert {1, nil} = PoisoningAttack.insert_all([attack_params(token_transfer)])

      assert {1, nil} =
               PoisoningAttack.insert_all([attack_params(token_transfer, %{score: 9, rules: ["scam_flag"]})])

      assert [%PoisoningAttack{score: 9, rules: ["scam_flag"]}] = Repo.all(PoisoningAttack)
    end
  end

  describe "preload_for_token_transfers/2" do
    test "returns an empty list for an empty list" do
      assert PoisoningAttack.preload_for_token_transfers([]) == []
    end

    test "attaches the recorded attack to its transfer and nil to the others" do
      flagged = insert_token_transfer()
      clean = insert_token_transfer()
      attack = insert(:token_transfer_poisoning_attack, token_transfer: flagged)

      assert [%{poisoning_attack: %PoisoningAttack{} = preloaded}, %{poisoning_attack: nil}] =
               PoisoningAttack.preload_for_token_transfers([flagged, clean])

      assert preloaded.block_hash == attack.block_hash
      assert preloaded.log_index == attack.log_index
      assert preloaded.score == attack.score
    end

    test "matches on both block hash and log index" do
      # same log index in another block must not be picked up
      flagged = insert_token_transfer()
      insert(:token_transfer_poisoning_attack, token_transfer: flagged)

      same_index_other_block =
        insert(:token_transfer,
          transaction: :transaction |> insert() |> with_block(),
          log_index: flagged.log_index
        )

      assert [%{poisoning_attack: nil}] = PoisoningAttack.preload_for_token_transfers([same_index_other_block])
    end

    test "passes nil entries through" do
      token_transfer = insert_token_transfer()

      assert [nil, %{poisoning_attack: nil}] = PoisoningAttack.preload_for_token_transfers([nil, token_transfer])
    end
  end
end
