defmodule BlockScoutWeb.API.V2.CeloController do
  use BlockScoutWeb, :controller

  import Explorer.Helper, only: [safe_parse_non_negative_integer: 1]

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 4,
      split_list_by_page: 1
    ]

  import BlockScoutWeb.PagingHelper, only: [delete_parameters_from_next_page_params: 1]

  alias Explorer.Chain.Celo.{Epoch, ElectionReward}

  @api_true [api?: true]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def epochs(conn, _params) do
  end

  def epoch(conn, %{"number" => number_string}) do
    options = [
      necessity_by_association: %{
        :distribution => :optional
      },
      api?: true
    ]

    with {:ok, number} <- parse_epoch_number(number_string),
         {:ok, epoch} <- Epoch.from_number(number, options) do
      aggregated_rewards = ElectionReward.epoch_number_to_rewards_aggregated_by_type(epoch.number, options)

      conn
      |> render(:celo_epoch, %{
        epoch: epoch,
        aggregated_election_rewards: aggregated_rewards
      })
    end
  end

  def election_rewards(conn, %{"number" => epoch_number_string, "type" => reward_type} = params) do
    with {:ok, number} <- parse_epoch_number(epoch_number_string),
         {:ok, reward_type_atom} <- parse_celo_reward_type(reward_type) do
      address_associations = [:names, :smart_contract, proxy_implementations_association()]

      full_options =
        [
          necessity_by_association: %{
            [account_address: address_associations] => :optional,
            [associated_account_address: address_associations] => :optional
          }
        ]
        |> Keyword.merge(ElectionReward.epoch_paging_options(params))
        |> Keyword.merge(@api_true)

      rewards_plus_one =
        ElectionReward.epoch_number_and_type_to_rewards(
          number,
          reward_type_atom,
          full_options
        )

      {rewards, next_page} = split_list_by_page(rewards_plus_one)

      filtered_params = params |> Map.drop(["number", "type"])

      next_page_params =
        next_page_params(
          next_page,
          rewards,
          filtered_params,
          &ElectionReward.to_epoch_paging_params/1
        )

      conn
      |> render(:celo_epoch_election_rewards, %{
        rewards: rewards,
        next_page_params: next_page_params
      })
    end
  end

  defp parse_epoch_number(number) do
    case safe_parse_non_negative_integer(number) do
      {:ok, epoch_number} -> {:ok, epoch_number}
      _ -> {:error, {:invalid, :number}}
    end
  end

  defp parse_celo_reward_type(reward_type_string) do
    reward_type_string
    |> ElectionReward.type_from_url_string()
    |> case do
      {:ok, type} -> {:ok, type}
      :error -> {:error, {:invalid, :celo_election_reward_type}}
    end
  end
end
