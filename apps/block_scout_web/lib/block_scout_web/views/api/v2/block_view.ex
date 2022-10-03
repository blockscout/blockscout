defmodule BlockScoutWeb.API.V2.BlockView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.{ApiView, Helper}

  def render("message.json", assigns) do
    ApiView.render("message.json", assigns)
  end

  def render("blocks.json", %{blocks: blocks, next_page_params: next_page_params}) do
    %{"items" => Enum.map(blocks, &prepare_block/1), "next_page_params" => next_page_params}
  end

  def render("block.json", %{block: block, tx_count: block_transaction_count}) do
    prepare_block(block, block_transaction_count)
  end

  def prepare_block(block, transaction_count \\ nil) do
    %{
      "height" => block.number,
      "timestamp" => block.timestamp,
      "tx_count" => transaction_count,
      "miner" => Helper.address_with_info(block.miner, block.miner_hash),
      "size" => block.size,
      "hash" => block.hash,
      "parent_hash" => block.parent_hash,
      "difficulty" => block.difficulty,
      "total_difficulty" => block.total_difficulty,
      "gas_used" => block.gas_used,
      "gas_limit" => block.gas_limit,
      "nonce" => block.nonce,
      "base_fee_per_gas" => block.base_fee_per_gas,
      "burnt_fees" => "TODO",
      "priority_fee" => 0,
      "extra_data" => "TODO",
      "sha3_uncles" => "TODO",
      "state_root" => "TODO",
      "reward" => "TODO",
      "gas_target" => "TODO",
      "burnt_fees_ratio" => "TODO"
    }
  end
end
