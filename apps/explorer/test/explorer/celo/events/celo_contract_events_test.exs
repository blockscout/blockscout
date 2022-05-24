defmodule Explorer.Celo.Events.CeloContractEventsTest do
  use Explorer.DataCase, async: true

  alias Explorer.Celo.ContractEvents.Accounts.AccountWalletAddressSetEvent
  alias Explorer.Celo.ContractEvents.EventTransformer
  alias Explorer.Celo.ContractEvents.EventMap
  alias Explorer.Celo.ContractEvents.Reserve.AssetAllocationSetEvent
  alias Explorer.Chain.{Address, CeloContractEvent, Log}
  alias Explorer.Test.TestParamCollisionEvent

  describe "overall generic tests" do
    test "exportisto event type parity" do
      # set of exportisto events taken from bigquery data set rc1_eksportisto_14
      exportisto_events =
        ~w(AccountCreated AccountDataEncryptionKeySet AccountMetadataURLSet AccountNameSet AccountSlashed AccountWalletAddressSet Approval AttestationCompleted AttestationExpiryBlocksSet AttestationIssuerSelected AttestationSignerAuthorized AttestationsRequested BitmapSetForInterval BlockGasLimitSet BucketsUpdated CarbonOffsettingFundSet ConstitutionSet DowntimeSlashPerformed ElectableValidatorsSet EpochRewardsDistributedToVoters ExchangeSpenderAdded Exchanged GasPriceMinimumUpdated GoldLocked GoldRelocked GoldUnlocked GoldWithdrawn HotfixApproved HotfixExecuted HotfixPrepared HotfixWhitelisted ImplementationSet MedianUpdated MinimumReportsSet OracleAdded OracleReportRemoved OracleReported OtherReserveAddressAdded OwnerSet OwnershipTransferred ParticipationBaselineQuorumFactorSet ParticipationBaselineUpdated ProposalApproved ProposalDequeued ProposalExecuted ProposalQueued ProposalUpvoteRevoked ProposalUpvoted ProposalVoted RandomnessBlockRetentionWindowSet ReferendumStageDurationSet RegistrySet RegistryUpdated ReserveFractionSet ReserveGoldTransferred Revocation SlashableDowntimeSet SlasherWhitelistAdded SlashingIncentivesSet SpenderAdded SpreadSet StableTokenSet TargetVotingGoldFractionSet TargetVotingYieldParametersSet TargetVotingYieldSet TargetVotingYieldUpdated TokenAdded Transfer TransferComment UpdateFrequencySet UptimeLookbackWindowSet ValidatorAffiliated ValidatorBlsPublicKeyUpdated ValidatorDeaffiliated ValidatorDeregistered ValidatorEcdsaPublicKeyUpdated ValidatorEpochPaymentDistributed ValidatorGroupActiveVoteRevoked ValidatorGroupCommissionUpdateQueued ValidatorGroupCommissionUpdated ValidatorGroupDeregistered ValidatorGroupMarkedEligible ValidatorGroupMarkedIneligible ValidatorGroupMemberAdded ValidatorGroupMemberRemoved ValidatorGroupMemberReordered ValidatorGroupPendingVoteRevoked ValidatorGroupRegistered ValidatorGroupVoteActivated ValidatorGroupVoteCast ValidatorRegistered ValidatorScoreUpdated ValidatorSignerAuthorized VoteSignerAuthorized Withdrawal)
        |> MapSet.new()

      blockscout_events =
        EventMap.map()
        |> Map.values()
        |> Enum.map(fn module ->
          event_name =
            module
            |> Atom.to_string()
            |> String.split(".")
            |> List.last()

          event_name |> String.split("Event") |> hd()
        end)
        |> MapSet.new()

      missing_events = MapSet.difference(exportisto_events, blockscout_events)

      assert MapSet.equal?(MapSet.new(), missing_events),
             "Blockscout events should be a superset of exsportisto events, found #{Enum.count(missing_events)} missing events: #{Enum.join(missing_events, ", ")}"
    end

    test "handling new events with property name collisions" do
      test_name = "event_parameter_test_name"
      test_topic = "event_parameter_test_topic"
      test_log_index = 555
      test_block_number = 444
      test_transaction_hash = "0x00000000000000000000000088c1c759600ec3110af043c183a2472ab32d099c"

      data =
        ABI.TypeEncoder.encode(
          [test_name, test_topic, test_log_index, test_block_number],
          [:string, :string, {:uint, 256}, {:uint, 256}],
          :output
        )
        |> Base.encode16(case: :lower)

      test_params = %{
        address_hash: "0x765de816845861e75a25fca122bb6898b8b1282a",
        block_hash: "0x42b21f09e9956d1a01195b1ca461059b2705fe850fc1977bd7182957e1b390d3",
        block_number: 10_913_664,
        data: "0x" <> data,
        first_topic: TestParamCollisionEvent.topic(),
        fourth_topic: nil,
        index: 8,
        second_topic: test_transaction_hash,
        third_topic: nil,
        transaction_hash: "0xb8960575a898afa8a124cd7414f1261109a119dba3bed4489393952a1556a5f0"
      }

      event = TestParamCollisionEvent |> struct!() |> EventTransformer.from_params(test_params)

      assert(
        event.__name == TestParamCollisionEvent.name(),
        "Event name should be available with underscored property name"
      )

      assert(event.name == test_name, "Generated property value should be available under the name")

      celo_event = event |> EventTransformer.to_celo_contract_event_params()

      assert(celo_event.name == TestParamCollisionEvent.name(), "CeloContractEvent name should be name of the event")
      assert(celo_event.params.name == test_name, "CeloContractEvent params should contain event property")
    end
  end

  describe "event parameter conversion tests" do
    test "converts events with unindexed address types correctly" do
      block_1 = insert(:block, number: 172_800)
      %Explorer.Chain.CeloCoreContract{address_hash: contract_address_hash} = insert(:core_contract)

      # event AccountWalletAddressSet with wallet_address as unindexed event parameter of type address
      # https://github.com/celo-org/data-services/issues/241
      log_data =
        %{
          "address" => contract_address_hash |> to_string(),
          "topics" => [
            "0xf81d74398fd47e35c36b714019df15f200f623dde569b5b531d6a0b4da5c5f26",
            "0x000000000000000000000000bcf444dc843a398c3436cc37729005378c3aae30"
          ],
          "data" => "0x0000000000000000000000005c3909164426a6bff52907d05c83c509ae427119",
          "blockNumber" => 172_800,
          "transactionHash" => nil,
          "transactionIndex" => nil,
          "blockHash" => block_1.hash |> to_string(),
          "logIndex" => "0x8",
          "removed" => false
        }
        |> EthereumJSONRPC.Log.to_elixir()
        |> EthereumJSONRPC.Log.elixir_to_params()

      changeset_params =
        EventMap.rpc_to_event_params([log_data])
        |> List.first()
        |> Map.put(:updated_at, Timex.now())
        |> Map.put(:inserted_at, Timex.now())

      # insert into db and assert that wallet_address is inserted as valid json
      {1, _} = Explorer.Repo.insert_all(CeloContractEvent, [changeset_params])

      # retrieve from db
      [event] = AccountWalletAddressSetEvent.query() |> EventMap.query_all()

      # wallet_address should decode to following value from "data" in log above
      assert(event.wallet_address |> to_string() == "0x5c3909164426a6bff52907d05c83c509ae427119")
    end

    test "converts arrays of bytes and ints" do
      block_1 = insert(:block, number: 172_800)
      %Explorer.Chain.CeloCoreContract{address_hash: contract_address_hash} = insert(:core_contract)

      # assets allocation set event from reserve contract
      # has both uint32[] and bytes32[] parameters in log data
      test_log = %Log{
        address_hash: contract_address_hash,
        block_hash: block_1.hash,
        block_number: 172_800,
        data: %Explorer.Chain.Data{
          bytes:
            <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 64, 0, 0, 0,
              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 99, 71, 76, 68, 0, 0, 0, 0,
              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 66, 84, 67, 0, 0, 0, 0, 0, 0, 0,
              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 69, 84, 72, 0, 0, 0, 0, 0, 0, 0, 0, 0,
              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 68, 65, 73, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99, 77, 67, 79, 50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
              105, 225, 13, 231, 102, 118, 208, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
              0, 0, 62, 119, 251, 103, 63, 3, 138, 96, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
              0, 0, 31, 195, 132, 43, 209, 240, 113, 192, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
              0, 0, 0, 10, 150, 129, 99, 240, 165, 123, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
              0, 0, 0, 0, 1, 15, 12, 240, 100, 221, 89, 32, 0, 0>>
        },
        first_topic: "0x55b488abd19ae7621712324d3d42c2ef7a9575f64f5503103286a1161fb40855",
        fourth_topic: nil,
        index: 0,
        second_topic: nil,
        third_topic: nil,
        transaction_hash: nil,
        type: nil
      }

      event =
        %AssetAllocationSetEvent{}
        |> EventTransformer.from_log(test_log)

      to_insert =
        event
        |> EventTransformer.to_celo_contract_event_params()
        |> Map.put(:inserted_at, Timex.now())
        |> Map.put(:updated_at, Timex.now())

      {1, _} = Explorer.Repo.insert_all(CeloContractEvent, [to_insert])

      [fetched_event] = AssetAllocationSetEvent.query() |> EventMap.query_all()

      expected_symbols = [
        [99, 71, 76, 68, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [66, 84, 67, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [69, 84, 72, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [68, 65, 73, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [99, 77, 67, 79, 50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      ]

      expected_weights = [
        500_000_000_000_000_000_000_000,
        295_000_000_000_000_000_000_000,
        150_000_000_000_000_000_000_000,
        50_000_000_000_000_000_000_000,
        5_000_000_000_000_000_000_000
      ]

      assert fetched_event.symbols == expected_symbols
      assert fetched_event.weights == expected_weights
    end
  end
end
