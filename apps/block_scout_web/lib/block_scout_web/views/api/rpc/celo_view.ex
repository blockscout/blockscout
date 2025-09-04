defmodule BlockScoutWeb.API.RPC.CeloView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView
  alias BlockScoutWeb.API.V2.CeloView, as: CeloViewV2

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def render("celo_epoch.json", %{epoch: epoch, aggregated_rewards: aggregated_rewards}) do
    distribution = epoch.distribution

    data = %{
      "epochNumber" => to_string(epoch.number),
      "type" => CeloViewV2.epoch_type(epoch),
      "isFinalized" => epoch.fetched?,
      "timestamp" =>
        epoch.end_processing_block &&
          epoch.end_processing_block.timestamp |> DateTime.to_unix() |> to_string(),
      "startProcessingBlockHash" => epoch.start_processing_block && to_string(epoch.start_processing_block.hash),
      "startProcessingBlockNumber" => epoch.start_processing_block && to_string(epoch.start_processing_block.number),
      "endProcessingBlockHash" => epoch.end_processing_block && to_string(epoch.end_processing_block.hash),
      "endProcessingBlockNumber" => epoch.end_processing_block && to_string(epoch.end_processing_block.number),
      "carbonOffsettingTargetEpochRewards" =>
        distribution.carbon_offsetting_transfer && distribution.carbon_offsetting_transfer.amount,
      "communityTargetEpochRewards" => distribution.community_transfer && distribution.community_transfer.amount,
      "reserveBolster" => distribution.reserve_bolster_transfer && distribution.reserve_bolster_transfer.amount,
      "voterTargetEpochRewards" => aggregated_rewards.voter && aggregated_rewards.voter.total,
      "validatorTargetEpochRewards" => aggregated_rewards.validator && aggregated_rewards.validator.total
    }

    RPCView.render("show.json", data: data)
  end

  def render("error.json", %{error: error}) do
    RPCView.render("error.json", error: error)
  end
end
