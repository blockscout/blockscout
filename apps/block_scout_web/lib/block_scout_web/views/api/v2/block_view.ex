defmodule BlockScoutWeb.API.V2.BlockView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.BlockView
  alias BlockScoutWeb.API.V2.{ApiView, Helper}
  alias Explorer.Chain.Block
  alias Explorer.Counters.BlockPriorityFeeCounter

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

  def prepare_block(block, _conn, single_block? \\ false) do
    burnt_fees = Block.burnt_fees(block.transactions, block.base_fee_per_gas)
    priority_fee = block.base_fee_per_gas && BlockPriorityFeeCounter.fetch(block.hash)

    transaction_fees = Block.transaction_fees(block.transactions)

    %{
      "height" => block.number,
      "timestamp" => block.timestamp,
      "tx_count" => count_transactions(block),
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
      "burnt_fees" => burnt_fees,
      "priority_fee" => priority_fee,
      # "extra_data" => "TODO",
      "uncles_hashes" => prepare_uncles(block.uncle_relations),
      # "state_root" => "TODO",
      "rewards" => prepare_rewards(block.rewards, block, single_block?),
      "gas_target_percentage" => Block.gas_target(block),
      "gas_used_percentage" => Block.gas_used_percentage(block),
      "burnt_fees_percentage" => burnt_fees_percentage(burnt_fees, transaction_fees),
      "type" => block |> BlockView.block_type() |> String.downcase(),
      "tx_fees" => transaction_fees,
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

  def count_transactions(%Block{transactions: txs}) when is_list(txs), do: Enum.count(txs)
  def count_transactions(_), do: nil

  def count_withdrawals(%Block{withdrawals: withdrawals}) when is_list(withdrawals), do: Enum.count(withdrawals)
  def count_withdrawals(_), do: nil

  case Application.compile_env(:explorer, :chain_type) do
    "rsk" ->
      defp chain_type_fields(result, block, single_block?) do
        if single_block? do
          result
          |> Map.put("minimum_gas_price", block.minimum_gas_price)
          |> Map.put("bitcoin_merged_mining_header", block.bitcoin_merged_mining_header)
          |> Map.put("bitcoin_merged_mining_coinbase_transaction", block.bitcoin_merged_mining_coinbase_transaction)
          |> Map.put("bitcoin_merged_mining_merkle_proof", block.bitcoin_merged_mining_merkle_proof)
          |> Map.put("hash_for_merged_mining", block.hash_for_merged_mining)
        else
          result
        end
      end

    "ethereum" ->
      defp chain_type_fields(result, block, single_block?) do
        if single_block? do
          blob_gas_price = Block.transaction_blob_gas_price(block.transactions)
          burnt_blob_transaction_fees = Decimal.mult(block.blob_gas_used || 0, blob_gas_price || 0)

          result
          |> Map.put("blob_gas_used", block.blob_gas_used)
          |> Map.put("excess_blob_gas", block.excess_blob_gas)
          |> Map.put("blob_gas_price", blob_gas_price)
          |> Map.put("burnt_blob_fees", burnt_blob_transaction_fees)
        else
          result
          |> Map.put("blob_gas_used", block.blob_gas_used)
          |> Map.put("excess_blob_gas", block.excess_blob_gas)
        end
      end

    _ ->
      defp chain_type_fields(result, _block, _single_block?) do
        result
      end
  end
end
