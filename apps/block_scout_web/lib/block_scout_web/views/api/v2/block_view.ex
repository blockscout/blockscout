defmodule BlockScoutWeb.API.V2.BlockView do
  use BlockScoutWeb, :view
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias BlockScoutWeb.BlockView
  alias BlockScoutWeb.API.V2.{ApiView, Helper}
  alias Explorer.Chain.Block

  def render("message.json", assigns) do
    ApiView.render("message.json", assigns)
  end

  def render("blocks.json", %{blocks: blocks, next_page_params: next_page_params}) do
    %{"items" => Enum.map(blocks, &prepare_block(&1, nil)), "next_page_params" => next_page_params}
  end

  def render("blocks.json", %{blocks: blocks}) do
    Enum.map(blocks, &prepare_block(&1, nil))
  end

  def render("block.json", %{block: block, conn: conn}) do
    prepare_block(block, conn, true)
  end

  def render("block.json", %{block: block, socket: _socket}) do
    # single_block? set to true in order to prevent heavy fetching of reward type
    prepare_block(block, nil, false)
  end

  def render("block_countdown.json", %{
        current_block: current_block,
        countdown_block: countdown_block,
        remaining_blocks: remaining_blocks,
        estimated_time_in_sec: estimated_time_in_sec
      }) do
    %{
      current_block_number: current_block,
      countdown_block_number: countdown_block,
      remaining_blocks_count: remaining_blocks,
      estimated_time_in_seconds: to_string(estimated_time_in_sec)
    }
  end

  def prepare_block(block, _conn, single_block? \\ false) do
    block = Block.aggregate_transactions(block)

    %{
      "height" => block.number,
      "timestamp" => block.timestamp,
      "transactions_count" => block.transactions_count,
      # todo: It should be removed in favour `transactions_count` property with the next release after 8.0.0
      "transaction_count" => block.transactions_count,
      "internal_transactions_count" => count_internal_transactions(block),
      "miner" => Helper.address_with_info(nil, block.miner, block.miner_hash, false),
      "size" => block.size,
      "hash" => block.hash,
      "parent_hash" => block.parent_hash,
      "difficulty" => block.difficulty,
      "total_difficulty" => block.total_difficulty,
      "gas_used" => block.gas_used,
      "gas_limit" => block.gas_limit,
      "nonce" => block.nonce,
      "base_fee_per_gas" => block.base_fee_per_gas,
      "burnt_fees" => block.burnt_fees,
      "priority_fee" => block.priority_fees,
      # "extra_data" => "TODO",
      "uncles_hashes" => prepare_uncles(block.uncle_relations),
      # "state_root" => "TODO",
      "rewards" => prepare_rewards(block.rewards, block, single_block?),
      "gas_target_percentage" => Block.gas_target(block),
      "gas_used_percentage" => Block.gas_used_percentage(block),
      "burnt_fees_percentage" => burnt_fees_percentage(block.burnt_fees, block.transactions_fees),
      "type" => block |> BlockView.block_type() |> String.downcase(),
      "transaction_fees" => block.transactions_fees,
      "withdrawals_count" => count_withdrawals(block)
    }
    |> chain_type_fields(block, single_block?)
  end

  def prepare_rewards(rewards, block, single_block?) do
    Enum.map(rewards, &prepare_reward(&1, block, single_block?))
  end

  def prepare_reward(reward, block, single_block?) do
    %{
      "reward" => reward.reward,
      "type" => if(single_block?, do: BlockView.block_reward_text(reward, block.miner.hash), else: reward.address_type)
    }
  end

  def prepare_uncles(uncles_relations) when is_list(uncles_relations) do
    Enum.map(uncles_relations, &prepare_uncle/1)
  end

  def prepare_uncles(_), do: []

  def prepare_uncle(uncle_relation) do
    %{"hash" => uncle_relation.uncle_hash}
  end

  def burnt_fees_percentage(_, %Decimal{coef: 0}), do: nil

  def burnt_fees_percentage(burnt_fees, transaction_fees)
      when not is_nil(transaction_fees) and not is_nil(burnt_fees) do
    burnt_fees |> Decimal.div(transaction_fees) |> Decimal.mult(100) |> Decimal.to_float()
  end

  def burnt_fees_percentage(_, _), do: nil

  defp count_internal_transactions(%Block{internal_transactions: internal_transactions})
       when is_list(internal_transactions),
       do: Enum.count(internal_transactions)

  defp count_internal_transactions(_), do: nil

  defp count_withdrawals(%Block{withdrawals: withdrawals}) when is_list(withdrawals), do: Enum.count(withdrawals)
  defp count_withdrawals(_), do: nil

  case @chain_type do
    :rsk ->
      defp chain_type_fields(result, block, single_block?) do
        if single_block? do
          # credo:disable-for-next-line Credo.Check.Design.AliasUsage
          BlockScoutWeb.API.V2.RootstockView.extend_block_json_response(result, block)
        else
          result
        end
      end

    :optimism ->
      defp chain_type_fields(result, block, single_block?) do
        if single_block? do
          # credo:disable-for-next-line Credo.Check.Design.AliasUsage
          BlockScoutWeb.API.V2.OptimismView.extend_block_json_response(result, block)
        else
          result
        end
      end

    :zksync ->
      defp chain_type_fields(result, block, single_block?) do
        if single_block? do
          # credo:disable-for-next-line Credo.Check.Design.AliasUsage
          BlockScoutWeb.API.V2.ZkSyncView.extend_block_json_response(result, block)
        else
          result
        end
      end

    :arbitrum ->
      defp chain_type_fields(result, block, single_block?) do
        if single_block? do
          # credo:disable-for-next-line Credo.Check.Design.AliasUsage
          BlockScoutWeb.API.V2.ArbitrumView.extend_block_json_response(result, block)
        else
          result
        end
      end

    :ethereum ->
      defp chain_type_fields(result, block, single_block?) do
        # credo:disable-for-next-line Credo.Check.Design.AliasUsage
        BlockScoutWeb.API.V2.EthereumView.extend_block_json_response(result, block, single_block?)
      end

    :celo ->
      defp chain_type_fields(result, block, single_block?) do
        # credo:disable-for-next-line Credo.Check.Design.AliasUsage
        BlockScoutWeb.API.V2.CeloView.extend_block_json_response(result, block, single_block?)
      end

    :zilliqa ->
      defp chain_type_fields(result, block, single_block?) do
        # credo:disable-for-next-line Credo.Check.Design.AliasUsage
        BlockScoutWeb.API.V2.ZilliqaView.extend_block_json_response(result, block, single_block?)
      end

    _ ->
      defp chain_type_fields(result, _block, _single_block?) do
        result
      end
  end
end
