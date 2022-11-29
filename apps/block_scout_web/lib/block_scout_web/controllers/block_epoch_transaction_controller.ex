defmodule BlockScoutWeb.BlockEpochTransactionController do
  use BlockScoutWeb, :controller

  import Explorer.Chain,
    only: [hash_to_block: 2, number_to_block: 2, string_to_address_hash: 1, string_to_block_hash: 1]

  alias BlockScoutWeb.{Controller, EpochTransactionView}
  alias Explorer.Celo.{AccountReader, EpochUtil, Util}
  alias Explorer.Chain
  alias Explorer.Chain.{CeloElectionRewards, CeloEpochRewards, Wei}
  alias Phoenix.View

  def index(conn, %{"block_hash_or_number" => formatted_block_hash_or_number, "type" => "JSON"}) do
    case param_block_hash_or_number_to_block(formatted_block_hash_or_number,
           necessity_by_association: %{
             [miner: :names] => :required,
             [celo_delegator: :celo_account] => :optional
           }
         ) do
      {:ok, block} ->
        epoch_rewards = CeloEpochRewards.get_celo_epoch_rewards_for_block(block.number)

        json(
          conn,
          %{
            items:
              epoch_rewards
              |> prepare_epoch_transaction_items(block)
          }
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

  def index(conn, %{"block_hash_or_number" => formatted_block_hash_or_number}) do
    case param_block_hash_or_number_to_block(formatted_block_hash_or_number,
           necessity_by_association: %{
             [miner: :names] => :required,
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
          epoch_transaction_count: EpochUtil.calculate_epoch_transaction_count_for_block(block.number, epoch_rewards),
          current_path: Controller.current_full_path(conn)
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

  defp get_epoch_transaction_address_strings(%{number: block_number}),
    do: [
      {:carbon,
       case AccountReader.get_carbon_offsetting_partner(block_number) do
         {:ok, address_string} ->
           address_string

         _ ->
           nil
       end},
      {:reserve,
       case Util.get_address("Reserve") do
         {:ok, address_string} ->
           address_string

         _ ->
           nil
       end},
      {:community,
       case Util.get_address("Governance") do
         {:ok, address_string} ->
           address_string

         _ ->
           nil
       end}
    ]

  defp get_epoch_transaction_address_hashes(%{number: _block_number} = block) do
    address_strings = get_epoch_transaction_address_strings(block)

    address_strings
    |> Enum.map(fn {type, address_string} ->
      if is_nil(address_string) do
        {type, nil}
      else
        case string_to_address_hash(address_string) do
          {:ok, address_hash} -> {type, address_hash}
          _ -> {type, nil}
        end
      end
    end)
    |> Map.new()
  end

  defp prepare_epoch_transaction_items(nil, _), do: []

  defp prepare_epoch_transaction_items(epoch_rewards, block) do
    addresses = get_epoch_transaction_address_hashes(block)

    carbon_epoch_transaction = %{
      address: addresses[:carbon],
      amount: get_carbon_fund_amount(epoch_rewards),
      block_number: block.number,
      date: block.timestamp,
      type: "carbon"
    }

    community_epoch_transaction = %{
      address: addresses[:community],
      amount: get_community_fund_amount(epoch_rewards),
      block_number: block.number,
      date: block.timestamp,
      type: "community"
    }

    carbon_transaction_json =
      View.render_to_string(
        EpochTransactionView,
        "_epoch_tile.html",
        epoch_transaction: carbon_epoch_transaction
      )

    community_transaction_json =
      View.render_to_string(
        EpochTransactionView,
        "_epoch_tile.html",
        epoch_transaction: community_epoch_transaction
      )

    items = [community_transaction_json, carbon_transaction_json]

    items_with_rewards_bolster =
      if Decimal.compare(epoch_rewards.reserve_bolster.value, 0) == :gt do
        reserve_bolster_epoch_transaction = %{
          address: addresses[:reserve],
          amount: get_reserve_bolster_amount(epoch_rewards),
          block_number: block.number,
          date: block.timestamp,
          type: "reserve-bolster"
        }

        reserve_bolster_transaction_json =
          View.render_to_string(
            EpochTransactionView,
            "_epoch_tile.html",
            epoch_transaction: reserve_bolster_epoch_transaction
          )

        [reserve_bolster_transaction_json | items]
      else
        items
      end

    total = CeloElectionRewards.get_aggregated_for_block_number(block.number)
    sample_rewards = CeloElectionRewards.get_sample_rewards_for_block_number(block.number)

    aggregated_tiles =
      Enum.map(
        [:voter, :group, :validator],
        fn type ->
          View.render_to_string(
            EpochTransactionView,
            "_election_aggregated_tile.html",
            block: block,
            reward_type: Atom.to_string(type),
            total: Map.get(total, type),
            rewards: Map.get(sample_rewards, type, [])
          )
        end
      )

    items_with_rewards_bolster ++ aggregated_tiles
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

  defp get_carbon_fund_amount(nil), do: nil

  defp get_carbon_fund_amount(epoch_rewards) do
    {:ok, zero_wei} = Wei.cast(0)
    epoch_rewards.carbon_offsetting_target_epoch_rewards || zero_wei
  end

  defp get_community_fund_amount(nil), do: nil

  defp get_community_fund_amount(epoch_rewards) do
    {:ok, zero_wei} = Wei.cast(0)
    epoch_rewards.community_target_epoch_rewards || zero_wei
  end

  defp get_reserve_bolster_amount(nil), do: nil

  defp get_reserve_bolster_amount(epoch_rewards) do
    {:ok, zero_wei} = Wei.cast(0)
    epoch_rewards.reserve_bolster || zero_wei
  end
end
