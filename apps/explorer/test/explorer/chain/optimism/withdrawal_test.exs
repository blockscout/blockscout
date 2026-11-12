# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Optimism.WithdrawalTest do
  use Explorer.DataCase

  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :optimism do
    alias Explorer.Application.Constants
    alias Explorer.Chain.Cache.{ChainId, OptimismFinalizationPeriod}
    alias Explorer.Chain.Data
    alias Explorer.Chain.Optimism.{DisputeGame, Withdrawal, WithdrawalEvent}
    alias Explorer.Utility.LogFirstTopic

    # MessagePassed(uint256 indexed nonce, address indexed sender, address indexed target, uint256 value, uint256 gasLimit, bytes data, bytes32 withdrawalHash)
    @message_passed_event "0x02a52367d10742d8032712c1bb8e0144ff1ec5ffda1ed7d70bb05a2744955054"

    # game types are taken from `GameTypes` library of the OP Stack contracts
    @retired_game_type 0
    @respected_game_type 1

    # game statuses are taken from `GameStatus` enum of the OP Stack contracts
    @game_status_in_progress 0
    @game_status_defender_wins 2

    @dispute_game_finality_delay_seconds 302_400
    @proof_maturity_delay_seconds 604_800

    @l2_block_number 123_456_789

    setup do
      # logs without `first_topic` are joined by `first_topic_id` only once the migration is started
      set_fill_logs_optimized_fields_migration_started()
      :ok
    end

    describe "list/1" do
      test "fills `msg_log_data` of `MessagePassed` logs stored with `compressed_data` only" do
        compressed_log_data = %Data{bytes: <<1, 2, 3>>}
        legacy_log_data = %Data{bytes: <<4, 5, 6>>}

        # imported by v12+: the payload is stored in `compressed_data` only
        insert_withdrawal_with_message_passed_log(1, data: nil, compressed_data: compressed_log_data)
        # not processed by the `fill_logs_compressed_data` migration yet
        insert_withdrawal_with_message_passed_log(2, data: legacy_log_data, compressed_data: nil)

        withdrawals = Withdrawal.list()

        assert [{2, legacy_log_data}, {1, compressed_log_data}] ==
                 Enum.map(withdrawals, &{Decimal.to_integer(&1.msg_nonce), &1.msg_log_data})

        refute Enum.any?(withdrawals, &Map.has_key?(&1, :msg_log_compressed_data))
      end
    end

    describe "transaction_statuses/1" do
      test "fills `msg_log_data` of a `MessagePassed` log stored with `compressed_data` only" do
        compressed_log_data = %Data{bytes: <<1, 2, 3>>}

        transaction =
          insert_withdrawal_with_message_passed_log(1, data: nil, compressed_data: compressed_log_data)

        assert [{1, _status, %{msg_log_data: ^compressed_log_data} = withdrawal}] =
                 Withdrawal.transaction_statuses(transaction.hash)

        refute Map.has_key?(withdrawal, :msg_log_compressed_data)
      end
    end

    describe "status/3" do
      setup do
        # the cache is shared between tests, so the current value is read
        # (without triggering the fallback) and restored after each test
        %{id: initial_chain_id} = ChainId.current_values([:id])
        ChainId.set_id(10)

        on_exit(fn -> ChainId.set_id(initial_chain_id) end)

        :ok
      end

      test "ignores a proof made against L2OutputOracle before Fault Proofs activation" do
        enable_fault_proofs(retired_days_ago: 800)
        withdrawal = withdrawal()

        # the `_l2OutputIndex` argument of the old proof is stored as `game_index`,
        # and a game with the same index was created later
        insert_proven_event(withdrawal, 900, game_index: 5)
        insert_game(5, created_days_ago: 500, resolved_days_ago: 496)

        insert_game(20, created_days_ago: 10, resolved_days_ago: 6)
        insert_proven_event(withdrawal, 2, game_index: 20)

        assert {"In challenge period", challenge_period_end} = Withdrawal.status(withdrawal)
        assert_in_delta DateTime.to_unix(challenge_period_end), DateTime.to_unix(days_ago(-5)), 5
      end

      test "ignores a proof made against L2OutputOracle when the retirement timestamp is unknown" do
        enable_fault_proofs()
        withdrawal = withdrawal()

        insert_proven_event(withdrawal, 900, game_index: 5)
        insert_game(5, created_days_ago: 500, resolved_days_ago: 496)

        insert_game(20, created_days_ago: 10, resolved_days_ago: 6)
        insert_proven_event(withdrawal, 2, game_index: 20)

        assert {"In challenge period", _} = Withdrawal.status(withdrawal)
      end

      test "ignores a proof made against a retired game" do
        enable_fault_proofs(retired_days_ago: 400)
        withdrawal = withdrawal()

        # the game was resolved in favor of the defender long ago, but then it was retired
        insert_game(3, game_type: @retired_game_type, created_days_ago: 700, resolved_days_ago: 696)
        insert_proven_event(withdrawal, 699, game_index: 3)

        insert_game(20, created_days_ago: 10, resolved_days_ago: 6)
        insert_proven_event(withdrawal, 2, game_index: 20)

        assert {"In challenge period", _} = Withdrawal.status(withdrawal)
      end

      test "ignores a proof bound to a retired game by its address" do
        enable_fault_proofs(retired_days_ago: 400)
        withdrawal = withdrawal()

        game = insert_game(3, game_type: @retired_game_type, created_days_ago: 700, resolved_days_ago: 696)
        insert_proven_event(withdrawal, 699, game_address_hash: game.address_hash)

        insert_game(20, created_days_ago: 10, resolved_days_ago: 6)

        assert {"Ready to prove", nil} == Withdrawal.status(withdrawal)
      end

      test "treats a withdrawal with void proofs only as an unproven one" do
        enable_fault_proofs(retired_days_ago: 400)
        withdrawal = withdrawal()

        insert_game(3, game_type: @retired_game_type, created_days_ago: 700, resolved_days_ago: 696)
        insert_proven_event(withdrawal, 699, game_index: 3)

        # the only respected game doesn't cover the withdrawal's L2 block yet
        insert_game(20, created_days_ago: 10, resolved_days_ago: 6, l2_block_number: withdrawal.l2_block_number - 1)

        assert {"Waiting for state root", nil} == Withdrawal.status(withdrawal)

        insert_game(21, created_days_ago: 1, resolved_days_ago: nil, l2_block_number: withdrawal.l2_block_number)

        assert {"Ready to prove", nil} == Withdrawal.status(withdrawal)
      end

      test "ignores a proof submitted at the creation timestamp of the game" do
        enable_fault_proofs(retired_days_ago: 800)
        withdrawal = withdrawal()

        # the proof is mature and the game is resolved, but OptimismPortal requires
        # the proof timestamp to be greater than the game creation timestamp
        game = insert_game(20, created_days_ago: 10, resolved_days_ago: 6)
        insert_proven_event(withdrawal, 10, game_index: 20, l1_timestamp: game.created_at)

        assert {"Ready to prove", nil} == Withdrawal.status(withdrawal)
      end

      test "ignores a proof made against L2OutputOracle when there are no indexed respected games" do
        enable_fault_proofs()
        withdrawal = withdrawal()

        # the respected game type is known, but the games of this type are not indexed yet
        insert_proven_event(withdrawal, 900, game_index: 5)
        insert_game(5, game_type: @retired_game_type, created_days_ago: 500, resolved_days_ago: 496)

        assert {"Waiting for state root", nil} == Withdrawal.status(withdrawal)
      end

      test "keeps the `Proven` status for a proof with unknown game when there are no indexed respected games" do
        enable_fault_proofs(retired_days_ago: 800)
        withdrawal = withdrawal()

        insert_proven_event(withdrawal, 2, [])

        assert {"Proven", nil} == Withdrawal.status(withdrawal)
      end

      test "returns `Ready for relay` for a mature proof made after the void one" do
        enable_fault_proofs(retired_days_ago: 800)
        withdrawal = withdrawal()

        insert_proven_event(withdrawal, 900, game_index: 5)
        insert_game(5, created_days_ago: 500, resolved_days_ago: 496)

        insert_game(20, created_days_ago: 20, resolved_days_ago: 16)
        insert_proven_event(withdrawal, 8, game_index: 20)

        assert {"Ready for relay", nil} == Withdrawal.status(withdrawal)
      end

      test "keeps the `Proven` status for a valid proof with unknown game" do
        enable_fault_proofs(retired_days_ago: 800)
        withdrawal = withdrawal()

        insert_game(20, created_days_ago: 10, resolved_days_ago: 6)
        # e.g. the proof was submitted through a contract, so the game is not available in the transaction input
        insert_proven_event(withdrawal, 2, [])

        assert {"Proven", nil} == Withdrawal.status(withdrawal)
      end

      test "doesn't ignore proofs when Fault Proofs are not active" do
        OptimismFinalizationPeriod.set_period(@proof_maturity_delay_seconds)
        on_exit(fn -> OptimismFinalizationPeriod.set_period(nil) end)

        withdrawal = withdrawal()

        # DisputeGameFactory can be deployed (and have games) before OptimismPortal starts using it
        insert_game(5, created_days_ago: 1, resolved_days_ago: nil)
        insert_proven_event(withdrawal, 8, game_index: 5)

        assert {"Ready for relay", nil} == Withdrawal.status(withdrawal)

        insert_proven_event(withdrawal, 2, game_index: 6)

        assert {"Ready for relay", nil} == Withdrawal.status(withdrawal)
      end

      test "returns `In challenge period` for a fresh proof when Fault Proofs are not active" do
        OptimismFinalizationPeriod.set_period(@proof_maturity_delay_seconds)
        on_exit(fn -> OptimismFinalizationPeriod.set_period(nil) end)

        withdrawal = withdrawal()
        insert_proven_event(withdrawal, 2, game_index: 6)

        assert {"In challenge period", challenge_period_end} = Withdrawal.status(withdrawal)
        assert_in_delta DateTime.to_unix(challenge_period_end), DateTime.to_unix(days_ago(-5)), 5
      end
    end

    # Makes the chain look like the one with active Fault Proofs: stores the constants
    # which are set by `Indexer.Fetcher.Optimism.DisputeGame`.
    defp enable_fault_proofs(opts \\ []) do
      Constants.set_constant_value("optimism_respected_game_type", Integer.to_string(@respected_game_type))

      Constants.set_constant_value(
        Withdrawal.dispute_game_finality_delay_seconds_constant(),
        Integer.to_string(@dispute_game_finality_delay_seconds)
      )

      Constants.set_constant_value(
        Withdrawal.proof_maturity_delay_seconds_constant(),
        Integer.to_string(@proof_maturity_delay_seconds)
      )

      case Keyword.get(opts, :retired_days_ago) do
        nil ->
          :ok

        retired_days_ago ->
          Constants.set_constant_value(
            Withdrawal.respected_game_type_updated_at_constant(),
            retired_days_ago |> days_ago() |> DateTime.to_unix() |> Integer.to_string()
          )
      end
    end

    # Builds the withdrawal info map the `status/3` function works with.
    defp withdrawal do
      %{hash: transaction_hash(), l2_block_number: @l2_block_number, l2_timestamp: nil, l1_transaction_hash: nil}
    end

    defp insert_proven_event(withdrawal, proven_days_ago, game_attrs) do
      Repo.insert!(
        struct(
          %WithdrawalEvent{
            withdrawal_hash: withdrawal.hash,
            l1_event_type: :WithdrawalProven,
            l1_timestamp: days_ago(proven_days_ago),
            l1_transaction_hash: transaction_hash(),
            # the older event, the lower L1 block number
            l1_block_number: 1_000_000 - proven_days_ago
          },
          game_attrs
        )
      )
    end

    defp insert_game(index, opts) do
      resolved_days_ago = Keyword.fetch!(opts, :resolved_days_ago)
      l2_block_number = Keyword.get(opts, :l2_block_number, @l2_block_number)

      Repo.insert!(%DisputeGame{
        index: index,
        game_type: Keyword.get(opts, :game_type, @respected_game_type),
        address_hash: address_hash(),
        extra_data: %Data{bytes: <<l2_block_number::size(256)>>},
        created_at: opts |> Keyword.fetch!(:created_days_ago) |> days_ago(),
        resolved_at: resolved_days_ago && days_ago(resolved_days_ago),
        status: if(resolved_days_ago, do: @game_status_defender_wins, else: @game_status_in_progress)
      })
    end

    defp days_ago(days), do: DateTime.add(DateTime.utc_now(), -days * 86_400, :second)

    # Inserts a withdrawal and its `MessagePassed` log, which keeps `first_topic`
    # only in `first_topic_id` as all logs imported by v12+ do.
    defp insert_withdrawal_with_message_passed_log(nonce, log_data_attrs) do
      transaction = :transaction |> insert() |> with_block()

      Repo.insert!(%Withdrawal{
        msg_nonce: Decimal.new(nonce),
        hash: transaction_hash(),
        l2_transaction_hash: transaction.hash,
        l2_block_number: transaction.block_number
      })

      insert(
        :log,
        [
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          first_topic: nil,
          first_topic_id: LogFirstTopic.find_or_create(@message_passed_event).id,
          second_topic: "0x" <> String.pad_leading(Integer.to_string(nonce, 16), 64, "0")
        ] ++ log_data_attrs
      )

      transaction
    end
  end
end
