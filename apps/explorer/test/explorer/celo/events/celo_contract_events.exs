defmodule Explorer.Celo.Events.CeloContractEventsTest do
  use Explorer.DataCase, async: true

  alias Explorer.Celo.ContractEvents.EventTransformer

  describe "overall generic tests" do
    @tag :skip
    test "exportisto event type parity" do
      # set of exportisto events taken from bigquery data set rc1_eksportisto_14
      exportisto_events =
        ~w(AccountCreated AccountDataEncryptionKeySet AccountMetadataURLSet AccountNameSet AccountSlashed AccountWalletAddressSet Approval AttestationCompleted AttestationExpiryBlocksSet AttestationIssuerSelected AttestationSignerAuthorized AttestationsRequested BitmapSetForInterval BlockGasLimitSet BucketsUpdated CarbonOffsettingFundSet ConstitutionSet DowntimeSlashPerformed ElectableValidatorsSet EpochRewardsDistributedToVoters ExchangeSpenderAdded Exchanged GasPriceMinimumUpdated GoldLocked GoldRelocked GoldUnlocked GoldWithdrawn HotfixApproved HotfixExecuted HotfixPrepared HotfixWhitelisted ImplementationSet MedianUpdated MinimumReportsSet OracleAdded OracleReportRemoved OracleReported OtherReserveAddressAdded OwnerSet OwnershipTransferred ParticipationBaselineQuorumFactorSet ParticipationBaselineUpdated ProposalApproved ProposalDequeued ProposalExecuted ProposalQueued ProposalUpvoteRevoked ProposalUpvoted ProposalVoted RandomnessBlockRetentionWindowSet ReferendumStageDurationSet RegistrySet RegistryUpdated ReserveFractionSet ReserveGoldTransferred Revocation SlashableDowntimeSet SlasherWhitelistAdded SlashingIncentivesSet SpenderAdded SpreadSet StableTokenSet TargetVotingGoldFractionSet TargetVotingYieldParametersSet TargetVotingYieldSet TargetVotingYieldUpdated TokenAdded Transfer TransferComment UpdateFrequencySet UptimeLookbackWindowSet ValidatorAffiliated ValidatorBlsPublicKeyUpdated ValidatorDeaffiliated ValidatorDeregistered ValidatorEcdsaPublicKeyUpdated ValidatorEpochPaymentDistributed ValidatorGroupActiveVoteRevoked ValidatorGroupCommissionUpdateQueued ValidatorGroupCommissionUpdated ValidatorGroupDeregistered ValidatorGroupMarkedEligible ValidatorGroupMarkedIneligible ValidatorGroupMemberAdded ValidatorGroupMemberRemoved ValidatorGroupMemberReordered ValidatorGroupPendingVoteRevoked ValidatorGroupRegistered ValidatorGroupVoteActivated ValidatorGroupVoteCast ValidatorRegistered ValidatorScoreUpdated ValidatorSignerAuthorized VoteSignerAuthorized Withdrawal)
        |> MapSet.new()

      blockscout_events =
        EventTransformer.__protocol__(:impls)
        |> then(fn {:consolidated, modules} -> Enum.map(modules, & &1.name()) end)
        |> MapSet.new()

      missing_events = MapSet.difference(exportisto_events, blockscout_events)

      assert MapSet.equal?(MapSet.new(), missing_events),
             "Blockscout events should be a superset of exsportisto events, found #{Enum.count(missing_events)} missing events: #{Enum.join(missing_events, ", ")}"
    end
  end
end
