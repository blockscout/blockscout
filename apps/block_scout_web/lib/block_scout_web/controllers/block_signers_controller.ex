defmodule BlockScoutWeb.BlockSignersController do
  use BlockScoutWeb, :controller

  import Explorer.Chain, only: [hash_to_block: 2, number_to_block: 2, string_to_block_hash: 1]

  alias Explorer.Celo.EpochUtil
  alias Explorer.Chain
  alias Explorer.Chain.CeloEpochRewards

  def index(conn, %{"block_hash_or_number" => formatted_block_hash_or_number}) do
    case param_block_hash_or_number_to_block(formatted_block_hash_or_number,
           necessity_by_association: %{
             [miner: :names] => :required,
             [{:signers, :validator_address, :names}] => :optional,
             [{:signers, :validator_address, :celo_delegator, :celo_account}] => :optional,
             [celo_delegator: :celo_account] => :optional,
             :uncles => :optional,
             :nephews => :optional,
             :rewards => :optional
           }
         ) do
      {:ok, block} ->
        block_transaction_count = Chain.block_to_transaction_count(block.hash)
        epoch_rewards = CeloEpochRewards.get_celo_epoch_rewards_for_block(block.number)

        render(
          conn,
          "index.html",
          block: block,
          block_transaction_count: block_transaction_count,
          current_path: current_path(conn),
          epoch_transaction_count: EpochUtil.calculate_epoch_transaction_count_for_block(block.number, epoch_rewards)
        )

      {:error, {:invalid, :hash}} ->
        not_found(conn)

      {:error, {:invalid, :number}} ->
        not_found(conn)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(
          "404.html",
          block: nil,
          block_above_tip: block_above_tip(formatted_block_hash_or_number)
        )
    end
  end

  defp param_block_hash_or_number_to_block("0x" <> _ = param, options) do
    case string_to_block_hash(param) do
      {:ok, hash} ->
        hash_to_block(hash, options)

      :error ->
        {:error, {:invalid, :hash}}
    end
  end

  defp param_block_hash_or_number_to_block(number_string, options)
       when is_binary(number_string) do
    case BlockScoutWeb.Chain.param_to_block_number(number_string) do
      {:ok, number} ->
        number_to_block(number, options)

      {:error, :invalid} ->
        {:error, {:invalid, :number}}
    end
  end

  defp block_above_tip("0x" <> _), do: {:error, :hash}

  defp block_above_tip(block_hash_or_number) when is_binary(block_hash_or_number) do
    case Chain.max_consensus_block_number() do
      {:ok, max_consensus_block_number} ->
        {block_number, _} = Integer.parse(block_hash_or_number)
        {:ok, block_number > max_consensus_block_number}

      {:error, :not_found} ->
        {:ok, true}
    end
  end
end
