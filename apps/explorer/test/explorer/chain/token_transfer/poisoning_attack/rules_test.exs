# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.RulesTest do
  use ExUnit.Case, async: true

  alias Explorer.Chain.{Hash, Token, TokenTransfer}
  alias Explorer.Chain.TokenTransfer.PoisoningAttack.{Config, Context, Result, Rules}

  doctest Rules, import: true

  @victim "0x1111111111111111111111111111111111111111"
  @recipient "0xab1200000000000000000000000000000000cd34"
  @mimic "0xab12ffffffffffffffffffffffffffffffffcd34"
  @stranger "0x2222222222222222222222222222222222222222"
  @attacker "0x3333333333333333333333333333333333333333"
  @token_contract "0x4444444444444444444444444444444444444444"
  @accepted_contract "0x5555555555555555555555555555555555555555"
  @block "0x0000000000000000000000000000000000000000000000000000000000000001"

  defp hash(string) do
    {:ok, hash} = Hash.Address.cast(string)
    hash
  end

  defp block_hash do
    {:ok, hash} = Hash.Full.cast(@block)
    hash
  end

  defp transfer(from, to, amount) do
    %TokenTransfer{
      from_address_hash: hash(from),
      to_address_hash: hash(to),
      token_contract_address_hash: hash(@token_contract),
      amount: amount && Decimal.new(amount),
      block_hash: block_hash(),
      block_number: 100,
      log_index: 1,
      token_type: "ERC-20"
    }
  end

  defp token(attrs \\ []) do
    struct!(
      %Token{
        contract_address_hash: hash(@token_contract),
        symbol: "FAKE",
        name: "Fake Token",
        decimals: Decimal.new(18)
      },
      attrs
    )
  end

  # A fake outgoing transfer: attacker's transaction emits Transfer(victim -> mimic, amount)
  defp fake_outgoing(attrs \\ []) do
    token_transfer = transfer(@victim, @mimic, 0)

    struct!(
      %Context{
        token_transfer: token_transfer,
        issuer: hash(@attacker),
        transaction_to: hash(@attacker),
        victim: hash(@victim),
        counterparty: hash(@mimic),
        amount: token_transfer.amount,
        token: token(),
        recipients: MapSet.new([hash(@recipient), hash(@stranger)]),
        known_assets: %{symbols: %{}, names: %{}}
      },
      attrs
    )
  end

  # A dust transfer: mimic itself sends a tiny amount to the victim
  defp dust_incoming(attrs \\ []) do
    token_transfer = transfer(@mimic, @victim, 5)

    struct!(
      %Context{
        token_transfer: token_transfer,
        issuer: hash(@mimic),
        transaction_to: hash(@token_contract),
        victim: hash(@victim),
        counterparty: hash(@mimic),
        amount: token_transfer.amount,
        token: token(),
        recipients: MapSet.new([hash(@recipient)]),
        known_assets: %{symbols: %{}, names: %{}}
      },
      attrs
    )
  end

  defp config(attrs \\ []), do: struct!(%Config{}, attrs)

  defp rule_names(%Result{rules: rules}), do: rules

  describe "orientations/2" do
    test "only the recipient can be the victim when the sender sent the transaction" do
      assert Rules.orientations(transfer(@mimic, @victim, 1), hash(@mimic)) == [{hash(@victim), hash(@mimic)}]
    end

    test "only the sender can be the victim when the recipient sent the transaction" do
      assert Rules.orientations(transfer(@victim, @mimic, 1), hash(@mimic)) == [{hash(@victim), hash(@mimic)}]
    end

    test "either side can be the victim when somebody else sent the transaction" do
      assert Rules.orientations(transfer(@victim, @mimic, 1), hash(@attacker)) ==
               [{hash(@victim), hash(@mimic)}, {hash(@mimic), hash(@victim)}]
    end

    test "either side can be the victim when the issuer is unknown" do
      assert length(Rules.orientations(transfer(@victim, @mimic, 1), nil)) == 2
    end

    test "a self-transfer is never scored" do
      assert Rules.orientations(transfer(@victim, @victim, 1), hash(@victim)) == []
    end
  end

  describe "candidate?/2" do
    test "a zero amount is a candidate" do
      assert Rules.candidate?(fake_outgoing(recipients: nil), config())
    end

    test "a sender mismatch is a candidate" do
      token_transfer = transfer(@victim, @stranger, 100)

      context =
        fake_outgoing(token_transfer: token_transfer, amount: token_transfer.amount, counterparty: hash(@stranger))

      assert Rules.candidate?(context, config())
    end

    test "positive dust from the counterparty is a candidate" do
      assert Rules.candidate?(dust_incoming(), config())
    end

    test "a normal transfer sent by its sender is not a candidate" do
      token_transfer = transfer(@stranger, @victim, Decimal.new("1000000000000000000"))

      context =
        dust_incoming(
          token_transfer: token_transfer,
          amount: token_transfer.amount,
          issuer: hash(@stranger),
          counterparty: hash(@stranger)
        )

      refute Rules.candidate?(context, config())
    end

    test "a sender mismatch explained by an attributed flow is not a candidate" do
      token_transfer = transfer(@victim, @stranger, 100)

      context =
        fake_outgoing(
          token_transfer: token_transfer,
          amount: token_transfer.amount,
          counterparty: hash(@stranger),
          participants: %{hash(@attacker) => %{contract?: true, attributed?: true, verified?: true}}
        )

      refute Rules.candidate?(context, config())
    end

    test "a mint is never a candidate" do
      refute Rules.candidate?(fake_outgoing(transfer_type: :token_minting), config())
    end
  end

  describe "evaluate/2 — classic fake outgoing transfer" do
    test "scores suspicious outgoing plus look-alike recipient" do
      result = Rules.evaluate(fake_outgoing(), config())

      assert result.score == 7
      assert rule_names(result) == ["lookalike_recipient", "suspicious_outgoing", "zero_amount", "sender_mismatch"]
      assert result.details["lookalike_recipient"]["matched_recipient"] == @recipient
      assert result.details["lookalike_recipient"]["prefix"] == "ab12"
      assert result.details["lookalike_recipient"]["suffix"] == "cd34"
      assert result.victim == hash(@victim)
      assert result.mimic == hash(@mimic)
      assert result.issuer == hash(@attacker)
      assert Result.attack?(result, config())
    end

    test "the other orientation of the same transfer does not score suspicious outgoing" do
      context = fake_outgoing(victim: hash(@mimic), counterparty: hash(@victim), recipients: MapSet.new())

      result = Rules.evaluate(context, config())

      refute "suspicious_outgoing" in rule_names(result)
      assert result.score == 0
    end

    test "nothing fires without an issuer except the look-alike" do
      result = Rules.evaluate(fake_outgoing(issuer: nil, transaction_to: nil), config())

      assert rule_names(result) == ["lookalike_recipient", "zero_amount"]
      assert result.score == 5
      assert result.issuer == nil
    end
  end

  describe "evaluate/2 — dust from a look-alike" do
    test "scores dust plus look-alike recipient" do
      result = Rules.evaluate(dust_incoming(), config())

      assert result.score == 6
      assert rule_names(result) == ["lookalike_recipient", "dust_from_counterparty"]
      assert result.details["dust_from_counterparty"] == %{"amount" => "5", "threshold" => "10000000000000000"}
    end

    test "uses the token specific raw threshold when configured" do
      config = config(dust_thresholds: %{hash(@token_contract) => Decimal.new(3)})

      result = Rules.evaluate(dust_incoming(), config)

      refute "dust_from_counterparty" in rule_names(result)
    end

    test "skips the default threshold when the decimals are unknown" do
      result = Rules.evaluate(dust_incoming(token: token(decimals: nil)), config())

      refute "dust_from_counterparty" in rule_names(result)
    end

    test "a zero amount is not dust" do
      token_transfer = transfer(@mimic, @victim, 0)
      result = Rules.evaluate(dust_incoming(token_transfer: token_transfer, amount: token_transfer.amount), config())

      refute "dust_from_counterparty" in rule_names(result)
      assert "zero_amount" in rule_names(result)
    end

    test "dust sent to the counterparty does not count" do
      token_transfer = transfer(@victim, @mimic, 5)

      result =
        Rules.evaluate(
          dust_incoming(token_transfer: token_transfer, amount: token_transfer.amount, issuer: hash(@victim)),
          config()
        )

      refute "dust_from_counterparty" in rule_names(result)
    end
  end

  describe "evaluate/2 — look-alike recipient" do
    test "does not fire for a counterparty already among the recipients" do
      context = fake_outgoing(recipients: MapSet.new([hash(@mimic), hash(@recipient)]))

      refute "lookalike_recipient" in rule_names(Rules.evaluate(context, config()))
    end

    test "does not fire when the recipients are not loaded" do
      refute "lookalike_recipient" in rule_names(Rules.evaluate(fake_outgoing(recipients: nil), config()))
    end

    test "does not fire when no recipient resembles the counterparty" do
      context = fake_outgoing(recipients: MapSet.new([hash(@stranger)]))

      refute "lookalike_recipient" in rule_names(Rules.evaluate(context, config()))
    end

    test "respects the configured prefix and suffix lengths" do
      # @recipient and @mimic share 4 leading and 4 trailing chars only
      refute "lookalike_recipient" in rule_names(Rules.evaluate(fake_outgoing(), config(prefix_length: 5)))
      refute "lookalike_recipient" in rule_names(Rules.evaluate(fake_outgoing(), config(suffix_length: 5)))
      assert "lookalike_recipient" in rule_names(Rules.evaluate(fake_outgoing(), config(prefix_length: 2)))
    end
  end

  describe "evaluate/2 — scam flag" do
    test "fires once for any flagged participant other than the victim and records who" do
      context = fake_outgoing(scam_hashes: MapSet.new([hash(@attacker), hash(@token_contract)]), recipients: nil)

      result = Rules.evaluate(context, config())

      assert "scam_flag" in rule_names(result)
      assert result.details["scam_flag"] == %{"participants" => ["token_contract", "issuer"]}
      # scam flag plus the suspicious outgoing transfer
      assert result.score == 5
    end

    test "the victim's own flag does not count" do
      context = fake_outgoing(scam_hashes: MapSet.new([hash(@victim)]), recipients: nil)

      refute "scam_flag" in rule_names(Rules.evaluate(context, config()))
    end

    test "flags the counterparty" do
      context = fake_outgoing(scam_hashes: MapSet.new([hash(@mimic)]), recipients: nil)

      assert Rules.evaluate(context, config()).details["scam_flag"] == %{"participants" => ["counterparty"]}
    end
  end

  describe "evaluate/2 — name imitation" do
    setup do
      known_assets = %{
        symbols: %{"usdt" => MapSet.new([hash(@accepted_contract)])},
        names: %{"tetherusd" => MapSet.new([hash(@accepted_contract)])}
      }

      %{known_assets: known_assets}
    end

    test "fires for a known symbol on a foreign unverified contract", %{known_assets: known_assets} do
      context = fake_outgoing(token: token(symbol: "USDT"), known_assets: known_assets, recipients: nil)

      result = Rules.evaluate(context, config())

      assert "name_imitation" in rule_names(result)
      assert result.score == 5

      assert result.details["name_imitation"] == %{
               "matched" => "symbol",
               "value" => "USDT",
               "accepted_contracts" => [@accepted_contract],
               "unverified" => true
             }
    end

    test "weighs a verified contract without the bonus", %{known_assets: known_assets} do
      context =
        fake_outgoing(
          token: token(symbol: "USDT"),
          known_assets: known_assets,
          recipients: nil,
          participants: %{hash(@token_contract) => %{contract?: true, attributed?: false, verified?: true}}
        )

      result = Rules.evaluate(context, config())

      assert result.score == 4
      assert result.details["name_imitation"]["unverified"] == false
    end

    test "matches the name after normalization", %{known_assets: known_assets} do
      context = fake_outgoing(token: token(name: "Tether  USD"), known_assets: known_assets, recipients: nil)

      assert Rules.evaluate(context, config()).details["name_imitation"]["matched"] == "name"
    end

    test "does not fire for an accepted contract", %{known_assets: known_assets} do
      token_transfer = %{transfer(@victim, @mimic, 0) | token_contract_address_hash: hash(@accepted_contract)}

      context =
        fake_outgoing(
          token_transfer: token_transfer,
          token: token(symbol: "USDT", contract_address_hash: hash(@accepted_contract)),
          known_assets: known_assets,
          recipients: nil
        )

      refute "name_imitation" in rule_names(Rules.evaluate(context, config()))
    end

    test "does not fire when the token is not cataloged", %{known_assets: known_assets} do
      refute "name_imitation" in rule_names(
               Rules.evaluate(fake_outgoing(token: nil, known_assets: known_assets), config())
             )
    end
  end

  describe "evaluate/2 — initiator fan-out" do
    test "fires at the threshold" do
      result = Rules.evaluate(fake_outgoing(fanout: 10, recipients: nil), config())

      assert "initiator_fanout" in rule_names(result)
      assert result.details["initiator_fanout"] == %{"distinct_participants" => 10}
    end

    test "does not fire below the threshold" do
      refute "initiator_fanout" in rule_names(Rules.evaluate(fake_outgoing(fanout: 9, recipients: nil), config()))
    end
  end

  describe "evaluate/2 — suppression" do
    test "a mint is not scored at all" do
      result = Rules.evaluate(fake_outgoing(transfer_type: :token_minting), config())

      assert result.score == 0
      assert result.rules == []
      assert result.suppressed == ["token_minting"]
    end

    test "an attributed flow suppresses the sender signals but keeps the others" do
      context =
        fake_outgoing(
          fanout: 50,
          scam_hashes: MapSet.new([hash(@token_contract)]),
          participants: %{hash(@attacker) => %{contract?: true, attributed?: true, verified?: true}}
        )

      result = Rules.evaluate(context, config())

      assert result.suppressed == ["sender_mismatch", "suspicious_outgoing", "initiator_fanout"]
      assert rule_names(result) == ["lookalike_recipient", "scam_flag", "zero_amount"]
      assert result.score == 8
    end

    test "an address from the ignored list suppresses the sender signals" do
      result = Rules.evaluate(fake_outgoing(), config(ignored_addresses: [hash(@attacker)]))

      assert "suspicious_outgoing" in result.suppressed
      assert result.score == 5
    end

    test "a legitimate router hop does not score" do
      # pool -> user leg of a swap: the user sent the transaction, the pool is a verified contract
      pool = @stranger
      token_transfer = transfer(pool, @victim, Decimal.new("5000000000000000000"))

      context =
        dust_incoming(
          token_transfer: token_transfer,
          amount: token_transfer.amount,
          issuer: hash(@victim),
          counterparty: hash(pool),
          participants: %{hash(pool) => %{contract?: true, attributed?: true, verified?: true}}
        )

      result = Rules.evaluate(context, config())

      assert result.score == 0
      assert result.rules == []
    end
  end

  describe "lookalike?/4" do
    test "compares prefix and suffix of the hex form" do
      assert Rules.lookalike?(hash(@recipient), hash(@mimic), 4, 4)
      refute Rules.lookalike?(hash(@recipient), hash(@mimic), 6, 4)
      refute Rules.lookalike?(hash(@recipient), hash(@stranger), 4, 4)
    end

    test "an address never resembles itself" do
      refute Rules.lookalike?(hash(@recipient), hash(@recipient), 4, 4)
    end
  end

  describe "normalize_asset_name/1" do
    test "drops case, separators and format characters" do
      assert Rules.normalize_asset_name("Tether USD") == "tetherusd"
      assert Rules.normalize_asset_name("tether-usd") == "tetherusd"
      assert Rules.normalize_asset_name("USD​T") == "usdt"
      assert Rules.normalize_asset_name("ＵＳＤＴ") == "usdt"
    end

    test "ignores names shorter than two characters" do
      assert Rules.normalize_asset_name("$") == nil
      assert Rules.normalize_asset_name("a") == nil
      assert Rules.normalize_asset_name(nil) == nil
    end
  end

  describe "Result.to_attack_params/1" do
    test "maps the verdict onto the attack row" do
      params = fake_outgoing() |> Rules.evaluate(config()) |> Result.to_attack_params()

      assert params.block_hash == block_hash()
      assert params.log_index == 1
      assert params.block_number == 100
      assert params.victim_address_hash == hash(@victim)
      assert params.mimic_address_hash == hash(@mimic)
      assert params.issuer_address_hash == hash(@attacker)
      assert params.score == 7
      assert params.token_contract_address_hash == hash(@token_contract)
    end
  end
end
