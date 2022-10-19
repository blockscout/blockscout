defmodule BlockScoutWeb.API.V2.BlockView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.BlockView
  alias BlockScoutWeb.API.V2.{ApiView, Helper}
  alias Explorer.Counters.{BlockBurnedFeeCounter, BlockPriorityFeeCounter}
  alias Explorer.Chain
  alias Explorer.Chain.{Block, Wei}

  def render("message.json", assigns) do
    ApiView.render("message.json", assigns)
  end

  def render("blocks.json", %{blocks: blocks, next_page_params: next_page_params}) do
    %{"items" => Enum.map(blocks, &prepare_block(&1, nil)), "next_page_params" => next_page_params}
  end

  def render("block.json", %{block: block, conn: conn}) do
    prepare_block(block, conn, true)
  end

  def render("block.json", %{block: block, socket: _socket}) do
    # single_block? set to true in order to prevent heavy fetching of reward type
    prepare_block(block, nil, false)
  end

  def prepare_block(block, conn, single_block? \\ false) do
    burned_fee = Chain.burned_fees(block.transactions, block.base_fee_per_gas)
    priority_fee = block.base_fee_per_gas && BlockPriorityFeeCounter.fetch(block.hash)

    tx_fees = Chain.txn_fees(block.transactions)

    %{
      "height" => block.number,
      "timestamp" => block.timestamp,
      "tx_count" => count_transactions(block),
      "miner" => Helper.address_with_info(conn, block.miner, block.miner_hash),
      "size" => block.size,
      "hash" => block.hash,
      "parent_hash" => block.parent_hash,
      "difficulty" => block.difficulty,
      "total_difficulty" => block.total_difficulty,
      "gas_used" => block.gas_used,
      "gas_limit" => block.gas_limit,
      "nonce" => block.nonce,
      "base_fee_per_gas" => block.base_fee_per_gas,
      "burnt_fees" => burned_fee,
      "priority_fee" => priority_fee,
      "extra_data" => "TODO",
      "uncles_hashes" => prepare_uncles(block.uncle_relations),
      "state_root" => "TODO",
      "rewards" => prepare_rewards(block.rewards, block, single_block?),
      "gas_target_percentage" => gas_target(block),
      "gas_used_percentage" => gas_used_percentage(block),
      "burnt_fees_percentage" => burnt_fees_percentage(burned_fee, tx_fees),
      "type" => block |> BlockView.block_type() |> String.downcase(),
      "tx_fees" => tx_fees
    }
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

  def gas_target(block) do
    elasticity_multiplier = 2
    ratio = Decimal.div(block.gas_used, Decimal.div(block.gas_limit, elasticity_multiplier))
    ratio |> Decimal.sub(1) |> Decimal.mult(100) |> Decimal.to_float()
  end

  def gas_used_percentage(block) do
    block.gas_used |> Decimal.div(block.gas_limit) |> Decimal.mult(100) |> Decimal.to_float()
  end

  def burnt_fees_percentage(_, %Decimal{coef: 0}), do: nil

  def burnt_fees_percentage(burnt_fees, tx_fees) when not is_nil(tx_fees) and not is_nil(burnt_fees) do
    burnt_fees.value |> Decimal.div(tx_fees) |> Decimal.mult(100) |> Decimal.to_float()
  end

  def burnt_fees_percentage(_, _), do: nil

  def count_transactions(%Block{transactions: txs}) when is_list(txs), do: Enum.count(txs)
  def count_transactions(_), do: nil
end
