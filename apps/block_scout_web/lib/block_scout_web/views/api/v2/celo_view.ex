defmodule BlockScoutWeb.API.V2.CeloView do
  require Logger

  import Explorer.Chain.Celo.Helper, only: [is_epoch_block: 1]

  alias BlockScoutWeb.API.V2.TokenView
  alias Ecto.Association.NotLoaded
  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Chain.Celo.Helper, as: CeloHelper
  alias Explorer.Chain.Celo.Epoch.Reward
  alias Explorer.Chain.Cache.CeloCoreContracts

  # def render("celo_epoch.json", )

  def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
    case {
      Map.get(transaction, :gas_token_contract_address),
      Map.get(transaction, :gas_token)
    } do
      {_, %NotLoaded{}} ->
        out_json

      {nil, _} ->
        out_json |> add_gas_token_field(nil)

      {gas_token_contract_address, nil} ->
        Logger.error(
          "Transaction #{transaction.hash} has a gas token contract address '#{gas_token_contract_address}' but no associated token found in the database"
        )

        out_json |> add_gas_token_field(nil)

      {gas_token_contract_address, gas_token} ->
        out_json
        |> add_gas_token_field(
          TokenView.render("token.json", %{
            token: gas_token,
            contract_address_hash: gas_token_contract_address
          })
        )
    end
  end

  defp maybe_add_epoch_reward(
        out_json,
        %Block{celo_epoch_reward: %Reward{} = reward} = block,
        true = _single_block?
      )
      when is_epoch_block(block.number) do
    Map.put(out_json, "epoch", %{
      reserve_bolster: reward.reserve_bolster,
      community_total: reward.community_total,
      voting_rewards_total: reward.voters_total
    })
  end

  defp maybe_add_epoch_reward(out_json, _block, _single_block?), do: out_json

  # @spec extend_block_json_response(map(), %{
  #         :__struct__ => Explorer.Chain.Block,
  #         :is_epoch => boolean(),
  #         optional(any()) => any()
  #       }) :: map()
  def extend_block_json_response(out_json, %Block{} = block, single_block?) do
    governance_contract_address_hash = CeloCoreContracts.get_address(:governance)

    celo_extra_data =
      %{
        "is_epoch_block" => CeloHelper.epoch_block?(block.number),
        "epoch_number" => CeloHelper.block_number_to_epoch_number(block.number),
        "community_fund_address_hash" => governance_contract_address_hash
      }
      |> maybe_add_epoch_reward(block, single_block?)

    Map.put(out_json, "celo", celo_extra_data)
  end

  defp add_gas_token_field(out_json, token_json) do
    out_json
    |> Map.put(
      "gas_token",
      token_json
    )
  end
end
