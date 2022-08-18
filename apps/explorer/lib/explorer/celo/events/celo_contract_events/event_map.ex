# This file is auto generated, changes will be lost upon regeneration
defmodule Explorer.Celo.ContractEvents.EventMap do
  @moduledoc "Map event names and event topics to concrete contract event structs"

  alias Explorer.Celo.AddressCache
  alias Explorer.Celo.ContractEvents.EventTransformer
  alias Explorer.Repo

  @doc "Convert ethrpc log parameters to CeloContractEvent insertion parameters"
  def rpc_to_event_params(logs) when is_list(logs) do
    logs
    |> Enum.map(fn params = %{first_topic: event_topic} ->
      case event_for_topic(event_topic) do
        nil ->
          nil

        event ->
          event
          |> struct!()
          |> EventTransformer.from_params(params)
          |> EventTransformer.to_celo_contract_event_params()
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc "Filter out log entries that do not come from celo core contracts"
  def filter_celo_contract_logs(logs) do
    logs
    |> Enum.filter(fn %{address_hash: contract_address} -> AddressCache.is_core_contract_address?(contract_address) end)
  end

  @doc "Filter out log entries that don't come from celo core contracts and convert them into celo contract event changeset params"
  def celo_rpc_to_event_params(logs) do
    logs
    |> filter_celo_contract_logs()
    |> rpc_to_event_params()
  end

  @doc "Convert CeloContractEvent instance to their concrete types"
  def celo_contract_event_to_concrete_event(events) when is_list(events) do
    events
    |> Enum.map(&celo_contract_event_to_concrete_event/1)
    |> Enum.reject(&is_nil/1)
  end

  def celo_contract_event_to_concrete_event(%{topic: topic} = params) do
    case event_for_topic(topic) do
      nil ->
        nil

      event ->
        event
        |> struct!()
        |> EventTransformer.from_celo_contract_event(params)
    end
  end

  @doc "Run ecto query and convert all CeloContractEvents into their concrete types"
  def query_all(query) do
    query
    |> Repo.all()
    |> celo_contract_event_to_concrete_event()
  end

  @doc "Convert concrete event to CeloContractEvent changeset parameters"
  def event_to_contract_event_params(events) when is_list(events) do
    events |> Enum.map(&event_to_contract_event_params/1)
  end

  def event_to_contract_event_params(event) do
    event |> EventTransformer.to_celo_contract_event_params()
  end

  @topic_to_event %{
    "0x815d292dbc1a08dfb3103aabb6611233dd2393903e57bdf4c5b3db91198a826c" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorGroupCommissionUpdatedEvent,
    "0x45aac85f38083b18efe2d441a65b9c1ae177c78307cb5a5d4aec8f7dbcaeabfe" =>
      Elixir.Explorer.Celo.ContractEvents.Election.ValidatorGroupVoteActivatedEvent,
    "0xddfdbe55eaaa70fe2b8bc82a9b0734c25cabe7cb6f1457f9644019f0b5ff91fc" =>
      Elixir.Explorer.Celo.ContractEvents.Governance.ParticipationBaselineQuorumFactorSetEvent,
    "0x3139419c41cdd7abca84fa19dd21118cd285d3e2ce1a9444e8161ce9fa62fdcd" =>
      Elixir.Explorer.Celo.ContractEvents.Reserve.SpenderAddedEvent,
    "0xa6e2c5a23bb917ba0a584c4b250257ddad698685829b66a8813c004b39934fe4" =>
      Elixir.Explorer.Celo.ContractEvents.Accounts.AccountNameSetEvent,
    "0xf8324c8592dfd9991ee3e717351afe0a964605257959e3d99b0eb3d45bff9422" =>
      Elixir.Explorer.Celo.ContractEvents.Sortedoracles.TokenReportExpirySetEvent,
    "0x954fa47fa6f4e8017b99f93c73f4fbe599d786f9f5da73fe9086ab473fb455d8" =>
      Elixir.Explorer.Celo.ContractEvents.Attestations.SelectIssuersWaitBlocksSetEvent,
    "0x60c5b4756af49d7b071b00dbf0f87af605cce11896ecd3b760d19f0f9d3fbcef" =>
      Elixir.Explorer.Celo.ContractEvents.Governance.ConstitutionSetEvent,
    "0xaf7f470b643316cf44c1f2898328a075e7602945b4f8584f48ba4ad2d8a2ea9d" =>
      Elixir.Explorer.Celo.ContractEvents.Attestations.AttestationIssuerSelectedEvent,
    "0xa9981ebfc3b766a742486e898f54959b050a66006dbce1a4155c1f84a08bcf41" =>
      Elixir.Explorer.Celo.ContractEvents.Sortedoracles.MedianUpdatedEvent,
    "0x414ff2c18c092697c4b8de49f515ac44f8bebc19b24553cf58ace913a6ac639d" =>
      Elixir.Explorer.Celo.ContractEvents.Attestations.AttestationCompletedEvent,
    "0x708a7934acb657a77a617b1fcd5f6d7d9ad592b72934841bff01acefd10f9b63" =>
      Elixir.Explorer.Celo.ContractEvents.Governance.HotfixExecutedEvent,
    "0xd19965d25ef670a1e322fbf05475924b7b12d81fd6b96ab718b261782efb3d62" =>
      Elixir.Explorer.Celo.ContractEvents.Governance.ProposalUpvotedEvent,
    "0x55b488abd19ae7621712324d3d42c2ef7a9575f64f5503103286a1161fb40855" =>
      Elixir.Explorer.Celo.ContractEvents.Reserve.AssetAllocationSetEvent,
    "0x38819cc49a343985b478d72f531a35b15384c398dd80fd191a14662170f895c6" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorGroupMemberReorderedEvent,
    "0x381545d9b1fffcb94ffbbd0bccfff9f1fb3acd474d34f7d59112a5c9973fee49" =>
      Elixir.Explorer.Celo.ContractEvents.Attestations.AttestationsRequestedEvent,
    "0x92a16cb9e1846d175c3007fc61953d186452c9ea1aa34183eb4b7f88cd3f07bb" =>
      Elixir.Explorer.Celo.ContractEvents.Lockedgold.SlasherWhitelistAddedEvent,
    "0x8f21dc7ff6f55d73e4fca52a4ef4fcc14fbda43ac338d24922519d51455d39c1" =>
      Elixir.Explorer.Celo.ContractEvents.Election.ValidatorGroupMarkedEligibleEvent,
    "0x8946f328efcc515b5cc3282f6cd95e87a6c0d3508421af0b52d4d3620b3e2db3" =>
      Elixir.Explorer.Celo.ContractEvents.Common.SpreadSetEvent,
    "0x3e069fb74dcf5fbc07740b0d40d7f7fc48e9c0ca5dc3d19eb34d2e05d74c5543" =>
      Elixir.Explorer.Celo.ContractEvents.Governance.ProposalDequeuedEvent,
    "0x35bc19e2c74829d0a96c765bb41b09ce24a9d0757486ced0d075e79089323638" =>
      Elixir.Explorer.Celo.ContractEvents.Attestations.AttestationsTransferredEvent,
    "0x828d2be040dede7698182e08dfa8bfbd663c879aee772509c4a2bd961d0ed43f" =>
      Elixir.Explorer.Celo.ContractEvents.Sortedoracles.OracleAddedEvent,
    "0x2717ead6b9200dd235aad468c9809ea400fe33ac69b5bfaa6d3e90fc922b6398" =>
      Elixir.Explorer.Celo.ContractEvents.Attestations.WithdrawalEvent,
    "0x90290eb9b27055e686a69fb810bada5381e544d07b8270021da2d355a6c96ed6" =>
      Elixir.Explorer.Celo.ContractEvents.Governance.ReferendumStageDurationSetEvent,
    "0xc3293b70d45615822039f6f13747ece88efbbb4e645c42070413a6c3fd21d771" =>
      Elixir.Explorer.Celo.ContractEvents.Downtimeslasher.SlashableDowntimeSetEvent,
    "0xe296227209b47bb8f4a76768ebd564dcde1c44be325a5d262f27c1fd4fd4538b" =>
      Elixir.Explorer.Celo.ContractEvents.Epochrewards.CarbonOffsettingFundSetEvent,
    "0x805996f252884581e2f74cf3d2b03564d5ec26ccc90850ae12653dc1b72d1fa2" =>
      Elixir.Explorer.Celo.ContractEvents.Accounts.AccountCreatedEvent,
    "0x1b76e38f3fdd1f284ed4d47c9d50ff407748c516ff9761616ff638c233107625" =>
      Elixir.Explorer.Celo.ContractEvents.Epochrewards.TargetVotingYieldParametersSetEvent,
    "0x6dc84b66cc948d847632b9d829f7cb1cb904fbf2c084554a9bc22ad9d8453340" =>
      Elixir.Explorer.Celo.ContractEvents.Sortedoracles.OracleRemovedEvent,
    "0x28ec9e38ba73636ceb2f6c1574136f83bd46284a3c74734b711bf45e12f8d929" =>
      Elixir.Explorer.Celo.ContractEvents.Governance.ProposalApprovedEvent,
    "0xe21a44017b6fa1658d84e937d56ff408501facdb4ff7427c479ac460d76f7893" =>
      Elixir.Explorer.Celo.ContractEvents.Sortedoracles.OracleReportRemovedEvent,
    "0x91ba34d62474c14d6c623cd322f4256666c7a45b7fdaa3378e009d39dfcec2a7" =>
      Elixir.Explorer.Celo.ContractEvents.Election.EpochRewardsDistributedToVotersEvent,
    "0x36a1aabe506bbe8802233cbb9aad628e91269e77077c953f9db3e02d7092ee33" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorBlsPublicKeyUpdatedEvent,
    "0xae7e034b0748a10a219b46074b20977a9170bf4027b156c797093773619a8669" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorGroupDeregisteredEvent,
    "0xc7666a52a66ff601ff7c0d4d6efddc9ac20a34792f6aa003d1804c9d4d5baa57" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorGroupMemberRemovedEvent,
    "0x27fe5f0c1c3b1ed427cc63d0f05759ffdecf9aec9e18d31ef366fc8a6cb5dc3b" =>
      Elixir.Explorer.Celo.ContractEvents.Common.RegistrySetEvent,
    "0x7dc46237a819c9171a9c037ec98928e563892905c4d23373ca0f3f500f4ed114" =>
      Elixir.Explorer.Celo.ContractEvents.Governance.ProposalUpvoteRevokedEvent,
    "0x0aa96aa275a5f936eed2a6a01f082594744dcc2510f575101366f8f479f03235" =>
      Elixir.Explorer.Celo.ContractEvents.Downtimeslasher.BitmapSetForIntervalEvent,
    "0xf6d22d0b43a6753880b8f9511b82b86cd0fe349cd580bbe6a25b6dc063ef496f" =>
      Elixir.Explorer.Celo.ContractEvents.Governance.HotfixWhitelistedEvent,
    "0x784c8f4dbf0ffedd6e72c76501c545a70f8b203b30a26ce542bf92ba87c248a4" =>
      Elixir.Explorer.Celo.ContractEvents.Reserve.TokenAddedEvent,
    "0x4166d073a7a5e704ce0db7113320f88da2457f872d46dc020c805c562c1582a0" =>
      Elixir.Explorer.Celo.ContractEvents.Registry.RegistryUpdatedEvent,
    "0xc1f217a1246a98ce04e938768309107630ed86c1e0e9f9995af28e23a9c06178" =>
      Elixir.Explorer.Celo.ContractEvents.Attestations.MaxAttestationsSetEvent,
    "0xab64f92ab780ecbf4f3866f57cee465ff36c89450dcce20237ca7a8d81fb7d13" =>
      Elixir.Explorer.Celo.ContractEvents.Common.ImplementationSetEvent,
    "0xf3709dc32cf1356da6b8a12a5be1401aeb00989556be7b16ae566e65fef7a9df" =>
      Elixir.Explorer.Celo.ContractEvents.Governance.ProposalVotedEvent,
    "0x43fdefe0a824cb0e3bbaf9c4bc97669187996136fe9282382baf10787f0d808d" =>
      Elixir.Explorer.Celo.ContractEvents.Accounts.AccountDataEncryptionKeySetEvent,
    "0x7cf8b633f218e9f9bc2c06107bcaddcfee6b90580863768acdcfd4f05d7af394" =>
      Elixir.Explorer.Celo.ContractEvents.Attestations.AttestationRequestFeeSetEvent,
    "0x49d8cdfe05bae61517c234f65f4088454013bafe561115126a8fe0074dc7700e" =>
      Elixir.Explorer.Celo.ContractEvents.Epochrewards.TargetVotingYieldUpdatedEvent,
    "0x5c8cd4e832f3a7d79f9208c2acf25a412143aa3f751cfd3728c42a0fea4921a8" =>
      Elixir.Explorer.Celo.ContractEvents.Election.ValidatorGroupMarkedIneligibleEvent,
    "0x119a23392e161a0bc5f9d5f3e2a6040c45b40d43a36973e10ea1de916f3d8a8a" =>
      Elixir.Explorer.Celo.ContractEvents.Common.StableTokenSetEvent,
    "0xe5d4e30fb8364e57bc4d662a07d0cf36f4c34552004c4c3624620a2c1d1c03dc" =>
      Elixir.Explorer.Celo.ContractEvents.Common.TransferCommentEvent,
    "0xc68a9b88effd8a11611ff410efbc83569f0031b7bc70dd455b61344c7f0a042f" =>
      Elixir.Explorer.Celo.ContractEvents.Sortedoracles.ReportExpirySetEvent,
    "0xd09501348473474a20c772c79c653e1fd7e8b437e418fe235d277d2c88853251" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorRegisteredEvent,
    "0x91ef92227057e201e406c3451698dd780fe7672ad74328591c88d281af31581d" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorAffiliatedEvent,
    "0x152c3fc1e1cd415804bc9ae15876b37e62d8909358b940e6f4847ca927f46637" =>
      Elixir.Explorer.Celo.ContractEvents.Epochrewards.TargetVotingYieldSetEvent,
    "0x6f184ec313435b3307a4fe59e2293381f08419a87214464c875a2a247e8af5e0" =>
      Elixir.Explorer.Celo.ContractEvents.Governance.HotfixPreparedEvent,
    "0xbf4b45570f1907a94775f8449817051a492a676918e38108bb762e991e6b58dc" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorGroupRegisteredEvent,
    "0x14d7ffb83f4265cb6fb62188eb603269555bf46efbc2923909ed7ac313d57af7" =>
      Elixir.Explorer.Celo.ContractEvents.Attestations.TransferApprovalEvent,
    "0x402ac9185b4616422c2794bf5b118bfcc68ed496d52c0d9841dfa114fdeb05ba" =>
      Elixir.Explorer.Celo.ContractEvents.Common.ExchangedEvent,
    "0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0" =>
      Elixir.Explorer.Celo.ContractEvents.Common.OwnershipTransferredEvent,
    "0x148075455e24d5cf538793db3e917a157cbadac69dd6a304186daf11b23f76fe" =>
      Elixir.Explorer.Celo.ContractEvents.Election.ValidatorGroupPendingVoteRevokedEvent,
    "0xf81d74398fd47e35c36b714019df15f200f623dde569b5b531d6a0b4da5c5f26" =>
      Elixir.Explorer.Celo.ContractEvents.Accounts.AccountWalletAddressSetEvent,
    "0x90c0a4a142fbfbc2ae8c21f50729a2f4bc56e85a66c1a1b6654f1e85092a54a6" =>
      Elixir.Explorer.Celo.ContractEvents.Common.UpdateFrequencySetEvent,
    "0x55311ae9c14427b0863f38ed97a2a5944c50d824bbf692836246512e6822c3cf" =>
      Elixir.Explorer.Celo.ContractEvents.Blockchainparameters.BlockGasLimitSetEvent,
    "0x337b24e614d34558109f3dee80fbcb3c5a4b08a6611bee45581772f64d1681e5" =>
      Elixir.Explorer.Celo.ContractEvents.Random.RandomnessBlockRetentionWindowSetEvent,
    "0xb1a3aef2a332070da206ad1868a5e327f5aa5144e00e9a7b40717c153158a588" =>
      Elixir.Explorer.Celo.ContractEvents.Lockedgold.GoldUnlockedEvent,
    "0xab4f92d461fdbd1af5db2375223d65edb43bcb99129b19ab4954004883e52025" =>
      Elixir.Explorer.Celo.ContractEvents.Escrow.WithdrawalEvent,
    "0xedf9f87e50e10c533bf3ae7f5a7894ae66c23e6cbbe8773d7765d20ad6f995e9" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorScoreUpdatedEvent,
    "0x0f0f2fc5b4c987a49e1663ce2c2d65de12f3b701ff02b4d09461421e63e609e7" =>
      Elixir.Explorer.Celo.ContractEvents.Lockedgold.GoldLockedEvent,
    "0x08523596abc266fb46d9c40ddf78fdfd3c08142252833ddce1a2b46f76521035" =>
      Elixir.Explorer.Celo.ContractEvents.Common.MinimumReportsSetEvent,
    "0x7abcb995a115c34a67528d58d5fc5ce02c22cb835ce1685046163f7d366d7111" =>
      Elixir.Explorer.Celo.ContractEvents.Lockedgold.AccountSlashedEvent,
    "0xae7458f8697a680da6be36406ea0b8f40164915ac9cc40c0dad05a2ff6e8c6a8" =>
      Elixir.Explorer.Celo.ContractEvents.Election.ValidatorGroupActiveVoteRevokedEvent,
    "0x4dd1abe16ad3d4f829372dc77766ca2cce34e205af9b10f8cc1fab370425864f" =>
      Elixir.Explorer.Celo.ContractEvents.Reserve.ReserveGoldTransferredEvent,
    "0x7cebb17173a9ed273d2b7538f64395c0ebf352ff743f1cf8ce66b437a6144213" =>
      Elixir.Explorer.Celo.ContractEvents.Sortedoracles.OracleReportedEvent,
    "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925" =>
      Elixir.Explorer.Celo.ContractEvents.Common.ApprovalEvent,
    "0x6e53b2f8b69496c2a175588ad1326dbabe2f66df4d82f817aeca52e3474807fb" =>
      Elixir.Explorer.Celo.ContractEvents.Gaspriceminimum.GasPriceMinimumUpdatedEvent,
    "0xa18ec663cb684011386aa866c4dacb32d2d2ad859a35d3440b6ce7200a76bad8" =>
      Elixir.Explorer.Celo.ContractEvents.Common.BucketsUpdatedEvent,
    "0x712ae1383f79ac853f8d882153778e0260ef8f03b504e2866e0593e04d2b291f" =>
      Elixir.Explorer.Celo.ContractEvents.Governance.ProposalExecutedEvent,
    "0x51131d2820f04a6b6edd20e22a07d5bf847e265a3906e85256fca7d6043417c5" =>
      Elixir.Explorer.Celo.ContractEvents.Governance.ParticipationBaselineUpdatedEvent,
    "0xb690f84efb1d9039c2834effb7bebc792a85bfec7ef84f4b269528454f363ccf" =>
      Elixir.Explorer.Celo.ContractEvents.Common.ReserveFractionSetEvent,
    "0xd3532f70444893db82221041edb4dc26c94593aeb364b0b14dfc77d5ee905152" =>
      Elixir.Explorer.Celo.ContractEvents.Election.ValidatorGroupVoteCastEvent,
    "0x9dfbc5a621c3e2d0d83beee687a17dfc796bbce2118793e5e254409bb265ca0b" =>
      Elixir.Explorer.Celo.ContractEvents.Accounts.AttestationSignerAuthorizedEvent,
    "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef" =>
      Elixir.Explorer.Celo.ContractEvents.Common.TransferEvent,
    "0xaab5f8a189373aaa290f42ae65ea5d7971b732366ca5bf66556e76263944af28" =>
      Elixir.Explorer.Celo.ContractEvents.Accounts.VoteSignerAuthorizedEvent,
    "0xbae2f33c70949fbc7325c98655f3039e5e1c7f774874c99fd4f31ec5f432b159" =>
      Elixir.Explorer.Celo.ContractEvents.Epochrewards.TargetVotingGoldFractionSetEvent,
    "0x3bff8b126c8f283f709ae37dc0d3fc03cae85ca4772cfb25b601f4b0b49ca6df" =>
      Elixir.Explorer.Celo.ContractEvents.Accounts.PaymentDelegationSetEvent,
    "0x557d39a57520d9835859d4b7eda805a7f4115a59c3a374eeed488436fc62a152" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorGroupCommissionUpdateQueuedEvent,
    "0x292d39ba701489b7f640c83806d3eeabe0a32c9f0a61b49e95612ebad42211cd" =>
      Elixir.Explorer.Celo.ContractEvents.Lockedgold.GoldWithdrawnEvent,
    "0x6f5937add2ec38a0fa4959bccd86e3fcc2aafb706cd3e6c0565f87a7b36b9975" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorEpochPaymentDistributedEvent,
    "0xbdf7e616a6943f81e07a7984c9d4c00197dc2f481486ce4ffa6af52a113974ad" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorGroupMemberAddedEvent,
    "0x484a24d7faca8c4330aaf9ba5f131e6bd474ed6877a555511f39d16a1d71d15a" =>
      Elixir.Explorer.Celo.ContractEvents.Blockchainparameters.UptimeLookbackWindowSetEvent,
    "0x4fbe976a07a9260091c2d347f8780c4bc636392e34d5b249b367baf8a5c7ca69" =>
      Elixir.Explorer.Celo.ContractEvents.Attestations.AttestationExpiryBlocksSetEvent,
    "0x6c464fad8039e6f09ec3a57a29f132cf2573d166833256960e2407eefff8f592" =>
      Elixir.Explorer.Celo.ContractEvents.Escrow.RevocationEvent,
    "0x36bc158cba244a94dc9b8c08d327e8f7e3c2ab5f1925454c577527466f04851f" =>
      Elixir.Explorer.Celo.ContractEvents.Governance.HotfixApprovedEvent,
    "0x0b5629fec5b6b5a1c2cfe0de7495111627a8cf297dced72e0669527425d3f01b" =>
      Elixir.Explorer.Celo.ContractEvents.Accounts.AccountMetadataURLSetEvent,
    "0x0fc2463e82c3b8a7868e75b68a76a144816d772687e5b09f45c02db37eedf4f6" =>
      Elixir.Explorer.Celo.ContractEvents.Escrow.TransferEvent,
    "0xb3ae64819ff89f6136eb58b8563cb32c6550f17eaf97f9ecc32f23783229f6de" =>
      Elixir.Explorer.Celo.ContractEvents.Election.ElectableValidatorsSetEvent,
    "0x16e382723fb40543364faf68863212ba253a099607bf6d3a5b47e50a8bf94943" =>
      Elixir.Explorer.Celo.ContractEvents.Accounts.ValidatorSignerAuthorizedEvent,
    "0x71815121f0622b31a3e7270eb28acb9fd10825ff418c9a18591f617bb8a31a6c" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorDeaffiliatedEvent,
    "0x1bfe527f3548d9258c2512b6689f0acfccdd0557d80a53845db25fc57e93d8fe" =>
      Elixir.Explorer.Celo.ContractEvents.Governance.ProposalQueuedEvent,
    "0x51407fafe7ef9bec39c65a12a4885a274190991bf1e9057fcc384fc77ff1a7f0" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorDeregisteredEvent,
    "0x716dc7c34384df36c6ccc5a2949f2ce9b019f5d4075ef39139a80038a4fdd1c3" =>
      Elixir.Explorer.Celo.ContractEvents.Common.SlashingIncentivesSetEvent,
    "0x50146d0e3c60aa1d17a70635b05494f864e86144a2201275021014fbf08bafe2" =>
      Elixir.Explorer.Celo.ContractEvents.Common.OwnerSetEvent,
    "0x213377eec2c15b21fa7abcbb0cb87a67e893cdb94a2564aa4bb4d380869473c8" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorEcdsaPublicKeyUpdatedEvent,
    "0x71bccdb89fff4d914e3d2e472b327e3debaf4c4d6f1dfe528f430447e4cbcf5f" =>
      Elixir.Explorer.Celo.ContractEvents.Reserve.ExchangeSpenderAddedEvent,
    "0xd78793225285ecf9cf5f0f84b1cdc335c2cb4d6810ff0b9fd156ad6026c89cea" =>
      Elixir.Explorer.Celo.ContractEvents.Reserve.OtherReserveAddressAddedEvent,
    "0x229d63d990a0f1068a86ee5bdce0b23fe156ff5d5174cc634d5da8ed3618e0c9" =>
      Elixir.Explorer.Celo.ContractEvents.Downtimeslasher.DowntimeSlashPerformedEvent,
    "0xa823fc38a01c2f76d7057a79bb5c317710f26f7dbdea78634598d5519d0f7cb0" =>
      Elixir.Explorer.Celo.ContractEvents.Lockedgold.GoldRelockedEvent
  }

  def event_for_topic(topic), do: Map.get(@topic_to_event, topic)
  def map, do: @topic_to_event
end
