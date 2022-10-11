defmodule BlockScoutWeb.API.V2.BlockView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.BlockView
  alias BlockScoutWeb.API.V2.{ApiView, Helper}
  alias Explorer.Counters.{BlockBurnedFeeCounter, BlockPriorityFeeCounter}
  alias Explorer.Chain.{Block, Wei}

  def render("message.json", assigns) do
    ApiView.render("message.json", assigns)
  end

  def render("blocks.json", %{blocks: blocks, next_page_params: next_page_params, conn: conn}) do
    %{"items" => Enum.map(blocks, &prepare_block(&1, conn)), "next_page_params" => next_page_params}
  end

  def render("block.json", %{block: block, conn: conn}) do
    prepare_block(block, conn)
  end

  def prepare_block(block, conn \\ nil) do
    burned_fee = block.base_fee_per_gas && Wei.mult(block.base_fee_per_gas, BlockBurnedFeeCounter.fetch(block.hash))
    priority_fee = block.base_fee_per_gas && BlockPriorityFeeCounter.fetch(block.hash)

    tx_fees =
      Enum.reduce(block.transactions, Decimal.new(0), fn %{gas_used: gas_used, gas_price: gas_price}, acc ->
        gas_used
        |> Decimal.mult(gas_price.value)
        |> Decimal.add(acc)
      end)

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
      "rewards" => prepare_rewards(block.rewards, block),
      "gas_target_percentage" => gas_target(block),
      "gas_used_percentage" => gas_used_percentage(block),
      "burnt_fees_percentage" => burnt_fees_percentage(burned_fee, tx_fees),
      "type" => block |> BlockView.block_type() |> String.downcase(),
      "tx_fees" => tx_fees
    }
  end

  def prepare_rewards(rewards, block) do
    Enum.map(rewards, &prepare_reward(&1, block))
  end

  def prepare_reward(reward, _block) do
    %{
      "reward" => reward.reward,
      # BlockView.block_reward_text(reward, block.miner.hash)
      "type" => reward.address_type
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
