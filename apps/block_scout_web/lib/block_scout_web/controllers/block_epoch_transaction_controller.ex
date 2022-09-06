defmodule BlockScoutWeb.BlockEpochTransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  import Explorer.Chain,
    only: [hash_to_block: 2, number_to_block: 2, string_to_address_hash: 1, string_to_block_hash: 1, hash_to_address: 1]

  alias BlockScoutWeb.{Controller, EpochTransactionView}
  alias Explorer.Celo.{AccountReader, EpochUtil}
  alias Explorer.Chain
  alias Explorer.Chain.{CeloElectionRewards, CeloEpochRewards, Wei}
  alias Phoenix.View

  alias Explorer.Celo.CoreContracts

  # The community fund address never changes, so it's ok to hard-code it.
  @community_fund_address "0xD533Ca259b330c7A88f74E000a3FaEa2d63B7972"

  def index(conn, %{"block_hash_or_number" => formatted_block_hash_or_number, "type" => "JSON"} = params) do
    case param_block_hash_or_number_to_block(formatted_block_hash_or_number,
           necessity_by_association: %{
             [miner: :names] => :required,
             [celo_delegator: :celo_account] => :optional
           }
         ) do
      {:ok, block} ->
        paging_options_keyword = paging_options(params)
        %Explorer.PagingOptions{page_size: page_size} = Keyword.get(paging_options_keyword, :paging_options)

        epoch_transactions_plus_one =
          CeloElectionRewards.get_paginated_rewards_for_block(block.number, Map.put(params, "page_size", page_size))

        {epoch_transactions, next_page} = split_list_by_page(epoch_transactions_plus_one)

        next_page_path =
          case next_page_params(next_page, epoch_transactions, params) do
            nil ->
              nil

            next_page_params ->
              block_epoch_transaction_path(conn, :index, block, Map.delete(next_page_params, "type"))
          end

        epoch_rewards = CeloEpochRewards.get_celo_epoch_rewards_for_block(block.number)

        json(
          conn,
          %{
            items:
              epoch_rewards
              |> prepare_epoch_transaction_items(block, epoch_transactions),
            next_page_path: next_page_path
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

  defp prepare_epoch_transaction_items(nil, _, _), do: []

  defp prepare_epoch_transaction_items(epoch_rewards, block, epoch_transactions) do
    carbon_fund_address =
      case AccountReader.get_carbon_offsetting_partner(block.number) do
        {:ok, address_string} ->
          {:ok, carbon_fund_address_hash} = string_to_address_hash(address_string)
          {:ok, carbon_fund_address} = hash_to_address(carbon_fund_address_hash)
          carbon_fund_address
        _ -> nil
      end

      reserve_address =
        case CoreContracts.contract_address("Reserve") do
          {:ok, address_string} ->
            {:ok, address_hash} = string_to_address_hash(address_string)
            {:ok, address} = hash_to_address(address_hash)
            address
          _ -> nil
        end

    {:ok, community_fund_address_hash} = string_to_address_hash(@community_fund_address)
    {:ok, community_fund_address} = hash_to_address(community_fund_address_hash)

    carbon_epoch_transaction = %{
      address: carbon_fund_address,
      amount: get_carbon_fund_amount(epoch_rewards),
      block_number: block.number,
      date: block.timestamp,
      type: "carbon"
    }

    community_epoch_transaction = %{
      address: community_fund_address,
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
      if Decimal.cmp(epoch_rewards.reserve_bolster.value, 0) == :gt do
        reserve_bolster_epoch_transaction = %{
          address: reserve_address,
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

    epoch_transactions_json =
      Enum.map(epoch_transactions, fn epoch_transaction ->
        View.render_to_string(
          EpochTransactionView,
          "_election_tile.html",
          epoch_transaction: epoch_transaction
        )
      end)

    items_with_rewards_bolster ++ epoch_transactions_json
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
