# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.DetectorTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Chain.{Address, Hash, SmartContract}
  alias Explorer.Repo
  alias Explorer.Chain.TokenTransfer.PoisoningAttack
  alias Explorer.Chain.TokenTransfer.PoisoningAttack.{Detector, Result}

  @recipient "0xab1200000000000000000000000000000000cd34"
  @mimic "0xab12ffffffffffffffffffffffffffffffffcd34"

  defp hash(string) do
    {:ok, hash} = Hash.Address.cast(string)
    hash
  end

  # A victim that once sent native coin to @recipient
  defp victim_with_history do
    victim = insert(:address)
    recipient = insert(:address, hash: hash(@recipient))

    :transaction
    |> insert(from_address: victim, to_address: recipient)
    |> with_block(insert(:block, number: 100))

    victim
  end

  defp token(attrs \\ []) do
    insert(:token, Keyword.merge([type: "ERC-20", symbol: "FAKE", name: "Fake", decimals: Decimal.new(18)], attrs))
  end

  # Transfer(from -> to, amount) emitted by a transaction `issuer` sent to `transaction_to`
  # Each transfer lands in its own block, all of them after the victim's history at block 100
  defp transfer(issuer, transaction_to, from, to, amount, token) do
    transaction =
      :transaction
      |> insert(from_address: issuer, to_address: transaction_to)
      |> with_block(insert(:block, number: 1_000 + System.unique_integer([:positive, :monotonic])))

    insert(:token_transfer,
      from_address: from,
      to_address: to,
      amount: amount,
      transaction: transaction,
      block: transaction.block,
      block_number: transaction.block_number,
      token_contract_address: token.contract_address,
      token_type: token.type
    )
  end

  defp entry(token_transfer, fanout \\ 0) do
    %{
      token_transfer: token_transfer,
      issuer: token_transfer.transaction.from_address_hash,
      transaction_to: token_transfer.transaction.to_address_hash,
      fanout: fanout
    }
  end

  describe "detect/2" do
    test "flags a fake outgoing transfer to a look-alike of a previous recipient" do
      victim = victim_with_history()
      mimic = insert(:address, hash: hash(@mimic))
      attacker = insert(:address)
      attacker_contract = insert(:contract_address)
      token = token()

      token_transfer = transfer(attacker, attacker_contract, victim, mimic, Decimal.new(0), token)

      assert [%Result{} = result] = Detector.detect([entry(token_transfer)])

      assert result.score == 7
      assert result.rules == ["lookalike_recipient", "suspicious_outgoing", "zero_amount", "sender_mismatch"]
      assert result.details["lookalike_recipient"]["matched_recipient"] == @recipient
      assert result.victim == victim.hash
      assert result.mimic == mimic.hash
      assert result.issuer == attacker.hash
      assert result.token_transfer.log_index == token_transfer.log_index
      assert Result.attack?(result, PoisoningAttack.Config.load())
    end

    test "flags dust sent by a look-alike directly" do
      victim = victim_with_history()
      mimic = insert(:address, hash: hash(@mimic))
      token = token()

      token_transfer = transfer(mimic, token.contract_address, mimic, victim, Decimal.new(5), token)

      assert [%Result{score: 6} = result] = Detector.detect([entry(token_transfer)])

      assert result.rules == ["lookalike_recipient", "dust_from_counterparty"]
      assert result.victim == victim.hash
      assert result.mimic == mimic.hash
      assert result.issuer == mimic.hash
    end

    test "picks the orientation with the higher score" do
      # The victim is the recipient here: the attacker's contract emits Transfer(mimic -> victim, 0)
      victim = victim_with_history()
      mimic = insert(:address, hash: hash(@mimic))
      attacker = insert(:address)
      attacker_contract = insert(:contract_address)
      token = token()

      token_transfer = transfer(attacker, attacker_contract, mimic, victim, Decimal.new(0), token)

      assert [%Result{score: 5} = result] = Detector.detect([entry(token_transfer)])

      assert result.victim == victim.hash
      assert result.mimic == mimic.hash
      assert "lookalike_recipient" in result.rules
    end

    test "scores a legitimate transfer zero without the look-alike lookup" do
      victim = victim_with_history()
      sender = insert(:address)
      token = token()

      token_transfer =
        transfer(sender, token.contract_address, sender, victim, Decimal.new("1000000000000000000"), token)

      assert [%Result{score: 0, rules: []}] = Detector.detect([entry(token_transfer)])
    end

    test "weighs a scam badge on the issuer" do
      victim = victim_with_history()
      stranger = insert(:address)
      attacker = insert(:address)
      attacker_contract = insert(:contract_address)
      token = token()
      insert(:scam_badge_to_address, address_hash: attacker.hash)

      token_transfer = transfer(attacker, attacker_contract, victim, stranger, Decimal.new(0), token)

      assert [%Result{score: 5} = result] = Detector.detect([entry(token_transfer)])

      assert result.rules == ["scam_flag", "suspicious_outgoing", "zero_amount", "sender_mismatch"]
      assert result.details["scam_flag"] == %{"participants" => ["issuer"]}
    end

    test "weighs the imitation of a known asset from the operator's list" do
      initial = Application.get_env(:explorer, PoisoningAttack) || []
      accepted = address_hash()

      Application.put_env(
        :explorer,
        PoisoningAttack,
        Keyword.merge(initial, known_assets_override: %{"USDT" => [to_string(accepted)]})
      )

      on_exit(fn -> Application.put_env(:explorer, PoisoningAttack, initial) end)

      victim = victim_with_history()
      stranger = insert(:address)
      attacker = insert(:address)
      token = token(symbol: "USDT")

      token_transfer = transfer(attacker, token.contract_address, victim, stranger, Decimal.new(0), token)

      assert [%Result{} = result] = Detector.detect([entry(token_transfer)])

      assert "name_imitation" in result.rules
      assert result.details["name_imitation"]["accepted_contracts"] == [to_string(accepted)]
      assert result.details["name_imitation"]["unverified"] == true
      # suspicious outgoing (2) + imitation (2) + unverified (1)
      assert result.score == 5
    end

    test "suppresses the sender signals of a flow through a verified contract" do
      victim = victim_with_history()
      stranger = insert(:address)
      user = insert(:address)
      router = Repo.get!(Address, insert(:smart_contract).address_hash)
      token = token()

      token_transfer = transfer(user, router, victim, stranger, Decimal.new("1000000000000000000"), token)

      assert [%Result{score: 0} = result] = Detector.detect([entry(token_transfer)])

      assert result.suppressed == ["sender_mismatch", "suspicious_outgoing"]
    end

    test "counts the fan-out handed in with the entry" do
      victim = victim_with_history()
      stranger = insert(:address)
      attacker = insert(:address)
      attacker_contract = insert(:contract_address)
      token = token()

      token_transfer = transfer(attacker, attacker_contract, victim, stranger, Decimal.new(0), token)

      assert [%Result{score: 3} = result] = Detector.detect([entry(token_transfer, 25)])
      assert "initiator_fanout" in result.rules
    end

    test "leaves out mints, burns and non-fungible transfers" do
      victim = victim_with_history()
      mimic = insert(:address, hash: hash(@mimic))
      attacker = insert(:address)
      attacker_contract = insert(:contract_address)
      {:ok, burn_address_hash} = Hash.Address.cast(SmartContract.burn_address_hash_string())
      burn_address = insert(:address, hash: burn_address_hash)
      erc20 = token()
      erc721 = token(type: "ERC-721")

      mint = transfer(attacker, attacker_contract, burn_address, victim, Decimal.new(0), erc20)
      burn = transfer(attacker, attacker_contract, victim, burn_address, Decimal.new(0), erc20)
      nft = transfer(attacker, attacker_contract, victim, mimic, nil, erc721)

      assert Detector.detect([entry(mint), entry(burn), entry(nft)]) == []
    end

    test "scores a transfer without a transaction from both sides" do
      victim = victim_with_history()
      mimic = insert(:address, hash: hash(@mimic))
      token = token()
      block = insert(:block, number: 200)

      token_transfer =
        insert(:token_transfer,
          from_address: victim,
          to_address: mimic,
          amount: Decimal.new(0),
          transaction: :transaction |> insert() |> with_block(block),
          block: block,
          block_number: block.number,
          token_contract_address: token.contract_address,
          token_type: token.type
        )

      assert [%Result{score: 5, issuer: nil} = result] =
               Detector.detect([%{token_transfer: token_transfer, issuer: nil, transaction_to: nil, fanout: 0}])

      assert result.victim == victim.hash
      assert result.mimic == mimic.hash
    end
  end
end
