defmodule BlockScoutWeb.API.V2.CeloController do
  use BlockScoutWeb, :controller

  import Explorer.Helper, only: [safe_parse_non_negative_integer: 1]

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 4,
      split_list_by_page: 1
    ]

  import Explorer.PagingOptions, only: [default_paging_options: 0]
  import BlockScoutWeb.PagingHelper, only: [delete_parameters_from_next_page_params: 1]

  alias Explorer.Chain.Hash
  alias Explorer.Chain.Celo.{ElectionReward, Epoch}
  alias Explorer.PagingOptions

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @doc """
  Handles GET requests to `/api/v2/celo/epochs` endpoint.
  """
  @spec epochs(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def epochs(conn, params) do
    paging_options =
      with {:ok, number_string} <- Map.fetch(params, "number"),
           {:ok, number} <- parse_epoch_number(number_string) do
        %{default_paging_options() | key: %{number: number}}
      else
        _ -> default_paging_options()
      end

    options = [
      necessity_by_association: %{
        :end_processing_block => :optional,
        :distribution => :optional
      },
      paging_options: paging_options,
      api?: true
    ]

    {epochs, next_page} =
      options
      |> Epoch.all()
      |> split_list_by_page()

    filtered_params =
      params
      |> delete_parameters_from_next_page_params()
      |> Map.drop(["number"])

    next_page_params =
      next_page_params(
        next_page,
        epochs,
        filtered_params,
        &%{number: &1.number}
      )

    conn
    |> render(:celo_epochs, %{
      epochs: epochs,
      next_page_params: next_page_params
    })
  end

  @doc """
  Handles GET requests to `/api/v2/celo/epochs/:number` endpoint.
  """
  @spec epoch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def epoch(conn, %{"number" => number_string}) do
    options = [
      necessity_by_association: %{
        :distribution => :optional,
        :start_processing_block => :optional,
        :end_processing_block => :optional
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

  @doc """
  Handles GET requests to `/api/v2/celo/epochs/:number/election-rewards/:type`
  endpoint.
  """
  @spec election_rewards(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def election_rewards(conn, %{"number" => epoch_number_string, "type" => reward_type} = params) do
    with {:ok, number} <- parse_epoch_number(epoch_number_string),
         {:ok, reward_type_atom} <- parse_celo_reward_type(reward_type) do
      address_associations = [:names, :smart_contract, proxy_implementations_association()]

      full_options = [
        necessity_by_association: %{
          [account_address: address_associations] => :optional,
          [associated_account_address: address_associations] => :optional
        },
        paging_options: election_rewards_paging_options(params),
        api?: true
      ]

      rewards_plus_one =
        ElectionReward.epoch_number_and_type_to_rewards(
          number,
          reward_type_atom,
          full_options
        )

      {rewards, next_page} = split_list_by_page(rewards_plus_one)

      filtered_params =
        params
        |> Map.drop([
          "number",
          "type",
          "amount",
          "account_address_hash",
          "associated_account_address_hash"
        ])

      next_page_params =
        next_page_params(
          next_page,
          rewards,
          filtered_params,
          &%{
            amount: &1.amount,
            account_address_hash: &1.account_address_hash,
            associated_account_address_hash: &1.associated_account_address_hash
          }
        )

      conn
      |> render(:celo_epoch_election_rewards, %{
        rewards: rewards,
        next_page_params: next_page_params
      })
    end
  end

  @spec election_rewards_paging_options(map()) :: PagingOptions.t()
  defp election_rewards_paging_options(params) do
    with %{
           "amount" => amount_string,
           "account_address_hash" => account_address_hash_string,
           "associated_account_address_hash" => associated_account_address_hash_string
         }
         when is_binary(amount_string) and
                is_binary(account_address_hash_string) and
                is_binary(associated_account_address_hash_string) <- params,
         {amount, ""} <- Decimal.parse(amount_string),
         true <- Decimal.compare(amount, Decimal.new(0)) == :gt,
         {:ok, account_address_hash} <- Hash.Address.cast(account_address_hash_string),
         {:ok, associated_account_address_hash} <-
           Hash.Address.cast(associated_account_address_hash_string) do
      %{
        default_paging_options()
        | key: %{
            amount: amount,
            account_address_hash: account_address_hash,
            associated_account_address_hash: associated_account_address_hash
          }
      }
    else
      _ -> default_paging_options()
    end
  end

  @spec parse_epoch_number(String.t()) ::
          {:ok, non_neg_integer()} | {:error, {:invalid, :number}}
  defp parse_epoch_number(number) do
    case safe_parse_non_negative_integer(number) do
      {:ok, epoch_number} when epoch_number < 32_768 -> {:ok, epoch_number}
      _ -> {:error, {:invalid, :number}}
    end
  end

  @spec parse_celo_reward_type(String.t()) ::
          {:ok, ElectionReward.type()} | {:error, {:invalid, :celo_election_reward_type}}
  defp parse_celo_reward_type(reward_type_string) do
    reward_type_string
    |> ElectionReward.type_from_url_string()
    |> case do
      {:ok, type} -> {:ok, type}
      :error -> {:error, {:invalid, :celo_election_reward_type}}
    end
  end
end
