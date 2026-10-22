# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.TokenTransferPoisoningTest do
  use Explorer.DataCase

  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.{Hash, TokenTransfer}
  alias Explorer.Chain.Address.ScamBadgeToAddress
  alias Explorer.Chain.TokenTransfer.PoisoningAttack
  alias Explorer.Repo
  alias Explorer.Tags.{AddressTag, AddressToTag}
  alias Indexer.Fetcher.TokenTransferPoisoning

  @moduletag :capture_log

  @recipient "0xab1200000000000000000000000000000000cd34"
  @mimic "0xab12ffffffffffffffffffffffffffffffffcd34"

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

    :ok
  end

  defp hash(string) do
    {:ok, hash} = Hash.Address.cast(string)
    hash
  end

  # A victim that once sent native coin to @recipient, and an attacker's
  # transaction emitting Transfer(victim -> mimic, 0) later on
  defp poisoning_scenario do
    victim = insert(:address)
    recipient = insert(:address, hash: hash(@recipient))
    mimic = insert(:address, hash: hash(@mimic))
    attacker = insert(:address)
    attacker_contract = insert(:contract_address)
    token = insert(:token, type: "ERC-20", decimals: Decimal.new(18))

    :transaction
    |> insert(from_address: victim, to_address: recipient)
    |> with_block(insert(:block, number: 100))

    transaction =
      :transaction
      |> insert(from_address: attacker, to_address: attacker_contract)
      |> with_block(insert(:block, number: 200))

    token_transfer =
      insert(:token_transfer,
        from_address: victim,
        to_address: mimic,
        amount: Decimal.new(0),
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        token_contract_address: token.contract_address,
        token_type: "ERC-20"
      )

    %{victim: victim, mimic: mimic, attacker: attacker, transaction: transaction, token_transfer: token_transfer}
  end

  describe "entries/2" do
    test "carries the transaction sender and recipient and the sender's fan-out" do
      %{transaction: transaction, token_transfer: token_transfer, attacker: attacker, victim: victim} =
        poisoning_scenario()

      other_victim = insert(:address)

      other_transfer =
        insert(:token_transfer,
          from_address: other_victim,
          to_address: build(:address),
          amount: Decimal.new(0),
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          token_type: "ERC-20"
        )

      assert [first, second] = TokenTransferPoisoning.entries([token_transfer, other_transfer], [transaction])

      assert first.issuer == attacker.hash
      assert first.transaction_to == transaction.to_address_hash
      # victim, mimic, other victim and its recipient
      assert first.fanout == 4
      assert second.fanout == 4
      assert %TokenTransfer{from_address_hash: from, log_index: log_index} = first.token_transfer
      assert from == victim.hash
      assert log_index == token_transfer.log_index
    end

    test "does not count the sender among the addresses it touched" do
      sender = insert(:address)
      transaction = :transaction |> insert(from_address: sender) |> with_block()

      token_transfer =
        insert(:token_transfer,
          from_address: sender,
          to_address: build(:address),
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          token_type: "ERC-20"
        )

      assert [%{fanout: 1}] = TokenTransferPoisoning.entries([token_transfer], [transaction])
    end

    test "leaves the issuer unknown for a transfer whose transaction is not in the batch" do
      %{token_transfer: token_transfer} = poisoning_scenario()

      assert [%{issuer: nil, transaction_to: nil, fanout: 0}] = TokenTransferPoisoning.entries([token_transfer], [])
    end

    test "leaves out transfers of other token types" do
      %{token_transfer: %TokenTransfer{} = token_transfer, transaction: transaction} = poisoning_scenario()

      nft = %{token_transfer | token_type: "ERC-721", amount: nil}
      untyped = %{token_transfer | token_type: nil}

      assert TokenTransferPoisoning.entries([nft, untyped], [transaction]) == []
    end
  end

  describe "run/2" do
    test "records a transfer scored as an attack" do
      %{transaction: transaction, token_transfer: token_transfer, victim: victim, mimic: mimic, attacker: attacker} =
        poisoning_scenario()

      entries = TokenTransferPoisoning.entries([token_transfer], [transaction])

      assert :ok = TokenTransferPoisoning.run(entries, nil)

      assert [%PoisoningAttack{} = attack] = PoisoningAttack |> PoisoningAttack.with_address_hashes() |> Repo.all()
      assert attack.block_hash == token_transfer.block_hash
      assert attack.log_index == token_transfer.log_index
      assert attack.victim_address_hash == victim.hash
      assert attack.mimic_address_hash == mimic.hash
      assert attack.issuer_address_hash == attacker.hash
      assert attack.score == 7
      assert "lookalike_recipient" in attack.rules

      # and the participants are marked
      assert Repo.get(ScamBadgeToAddress, attacker.hash)

      assert Repo.exists?(
               from(att in AddressToTag,
                 join: tag in AddressTag,
                 on: tag.id == att.tag_id,
                 where: att.address_hash == ^mimic.hash and tag.label == "phishing"
               )
             )

      refute Repo.get(ScamBadgeToAddress, victim.hash)
    end

    test "records nothing for a transfer below the threshold" do
      sender = insert(:address)
      transaction = :transaction |> insert(from_address: sender) |> with_block()

      token_transfer =
        insert(:token_transfer,
          from_address: sender,
          to_address: build(:address),
          amount: Decimal.new("1000000000000000000"),
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          token_type: "ERC-20"
        )

      entries = TokenTransferPoisoning.entries([token_transfer], [transaction])

      assert :ok = TokenTransferPoisoning.run(entries, nil)
      assert Repo.all(PoisoningAttack) == []
    end
  end

  describe "async_fetch/4" do
    setup do
      initial = Application.get_env(:indexer, TokenTransferPoisoning.Supervisor) || []
      on_exit(fn -> Application.put_env(:indexer, TokenTransferPoisoning.Supervisor, initial) end)

      %{initial_supervisor_config: initial}
    end

    test "scores the buffered transfers", %{initial_supervisor_config: initial} do
      Application.put_env(:indexer, TokenTransferPoisoning.Supervisor, Keyword.merge(initial, disabled?: false))

      %{transaction: transaction, token_transfer: token_transfer} = poisoning_scenario()

      TokenTransferPoisoning.Supervisor.Case.start_supervised!()

      assert :ok = TokenTransferPoisoning.async_fetch([token_transfer], [transaction], false)

      wait_for_attack()

      assert [%PoisoningAttack{score: 7}] = Repo.all(PoisoningAttack)
    end

    test "does nothing while the fetcher is disabled", %{initial_supervisor_config: initial} do
      Application.put_env(:indexer, TokenTransferPoisoning.Supervisor, Keyword.merge(initial, disabled?: true))

      %{transaction: transaction, token_transfer: token_transfer} = poisoning_scenario()

      assert :ok = TokenTransferPoisoning.async_fetch([token_transfer], [transaction], true)
      assert Repo.all(PoisoningAttack) == []
    end
  end

  # The verdict is recorded first and the participants marked afterwards; wait
  # for the last write so the task is done before the sandbox goes away
  defp wait_for_attack(attempts \\ 100) do
    if Repo.exists?(ScamBadgeToAddress) or attempts == 0 do
      :ok
    else
      Process.sleep(20)
      wait_for_attack(attempts - 1)
    end
  end
end
