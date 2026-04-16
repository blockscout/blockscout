defmodule BlockScoutWeb.API.V2.CeloController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import Explorer.Helper, only: [safe_parse_non_negative_integer: 1]

  import BlockScoutWeb.Chain,
    only: [
      paginate_list: 4
    ]

  import Explorer.PagingOptions, only: [default_paging_options: 0]

  alias BlockScoutWeb.Schemas.API.V2.ErrorResponses.NotFoundResponse
  alias Explorer.Chain.Celo.{AggregatedElectionReward, ElectionReward, Epoch}
  alias Explorer.Chain.Hash
  alias Explorer.PagingOptions

  @celo_reward_types ElectionReward.types()

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  tags(["celo"])

  operation :epochs,
    summary: "List Celo epochs.",
    description: "Retrieves a paginated list of Celo epochs.",
    parameters:
      base_params() ++
        define_paging_params([
          "number",
          "items_count"
        ]),
    responses: [
      ok:
        {"List of Celo epochs.", "application/json",
         paginated_response(
           items: Schemas.Celo.Epoch,
           next_page_params_example: %{
             "number" => 100,
             "items_count" => 50
           },
           title_prefix: "CeloEpochs"
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Handles GET requests to `/api/v2/celo/epochs` endpoint.
  """
  @spec epochs(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def epochs(conn, params) do
    paging_options =
      with {:ok, number_string} <- Map.fetch(params, :number),
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

    filtered_params =
      params
      |> Map.drop([:number])

    {epochs, next_page_params} =
      options
      |> Epoch.all()
      |> paginate_list(filtered_params, options[:paging_options], paging_function: &%{number: &1.number})

    conn
    |> render(:celo_epochs, %{
      epochs: epochs,
      next_page_params: next_page_params
    })
  end

  operation :epoch,
    summary: "Get Celo epoch details.",
    description: "Retrieves detailed information about a Celo epoch.",
    parameters: [
      %OpenApiSpex.Parameter{
        name: :number,
        in: :path,
        schema: Schemas.General.IntegerString,
        required: true,
        description: "Epoch number in the path."
      }
      | base_params()
    ],
    responses: [
      ok: {"Celo epoch details.", "application/json", Schemas.Celo.Epoch.Detailed},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]

  @doc """
  Handles GET requests to `/api/v2/celo/epochs/:number` endpoint.
  """
  @spec epoch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def epoch(conn, %{number: number_string}) do
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
      aggregated_rewards = AggregatedElectionReward.epoch_number_to_rewards_aggregated_by_type(epoch.number, api?: true)

      conn
      |> render(:celo_epoch, %{
        epoch: epoch,
        aggregated_election_rewards: aggregated_rewards
      })
    end
  end

  operation :election_rewards,
    summary: "List Celo epoch election rewards.",
    description: "Retrieves a paginated list of election rewards for a Celo epoch and reward type.",
    parameters:
      [
        %OpenApiSpex.Parameter{
          name: :number,
          in: :path,
          schema: Schemas.General.IntegerString,
          required: true,
          description: "Epoch number in the path."
        },
        %OpenApiSpex.Parameter{
          name: :type,
          in: :path,
          schema: Schemas.Celo.ElectionReward.Type,
          required: true,
          description: "Reward type in the path."
        }
        | base_params()
      ] ++
        define_paging_params([
          "amount",
          "account_address_hash",
          "associated_account_address_hash",
          "items_count"
        ]),
    responses: [
      ok:
        {"Election rewards for the specified Celo epoch.", "application/json",
         paginated_response(
           items: Schemas.Celo.ElectionReward,
           next_page_params_example: %{
             "amount" => "1000000000000000000",
             "account_address_hash" => "0x1234567890123456789012345678901234567890",
             "associated_account_address_hash" => "0x0987654321098765432109876543210987654321",
             "items_count" => 50
           },
           title_prefix: "CeloEpochElectionRewards"
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Handles GET requests to `/api/v2/celo/epochs/:number/election-rewards/:type`
  endpoint.
  """
  @spec election_rewards(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def election_rewards(conn, %{number: epoch_number_string, type: reward_type} = params) do
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

      filtered_params =
        params
        |> Map.drop([
          :number,
          :type,
          :amount,
          :account_address_hash,
          :associated_account_address_hash
        ])

      {rewards, next_page_params} =
        paginate_list(rewards_plus_one, filtered_params, full_options[:paging_options],
          paging_function:
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
           amount: amount_string,
           account_address_hash: account_address_hash_string,
           associated_account_address_hash: associated_account_address_hash_string
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

  @spec parse_epoch_number(non_neg_integer() | String.t()) ::
          {:ok, non_neg_integer()} | {:error, {:invalid, :number}}
  defp parse_epoch_number(epoch_number) when is_integer(epoch_number) and epoch_number >= 0 and epoch_number < 32_768,
    do: {:ok, epoch_number}

  defp parse_epoch_number(number) when is_binary(number) do
    case safe_parse_non_negative_integer(number) do
      {:ok, epoch_number} when epoch_number < 32_768 -> {:ok, epoch_number}
      _ -> {:error, {:invalid, :number}}
    end
  end

  defp parse_epoch_number(_), do: {:error, {:invalid, :number}}

  # Parses a reward type value produced by CastAndValidate.
  #
  # The OpenAPI schema enum (see `ElectionReward.type_enum_with_legacy/0`)
  # contains both atoms (:voter, :validator, :group, :delegated_payment)
  # and a legacy hyphenated string ("delegated-payment"). CastAndValidate
  # returns an atom when the URL segment matches `to_string(atom)`, but
  # passes "delegated-payment" through as a string because
  # `to_string(:delegated_payment)` is "delegated_payment" (underscore),
  # which does not match the hyphenated URL form.
  #
  # The atom clause handles the canonical types; the string clause handles
  # the legacy "delegated-payment" form via `type_from_url_string/1`.
  #
  # Once the legacy form is removed from the enum, the string clause and
  # catch-all can be deleted.
  @spec parse_celo_reward_type(atom() | String.t()) ::
          {:ok, ElectionReward.type()} | {:error, {:invalid, :celo_election_reward_type}}
  defp parse_celo_reward_type(reward_type) when reward_type in @celo_reward_types do
    {:ok, reward_type}
  end

  defp parse_celo_reward_type(reward_type_string) when is_binary(reward_type_string) do
    reward_type_string
    |> ElectionReward.type_from_url_string()
    |> case do
      {:ok, type} -> {:ok, type}
      :error -> {:error, {:invalid, :celo_election_reward_type}}
    end
  end

  defp parse_celo_reward_type(_), do: {:error, {:invalid, :celo_election_reward_type}}
end
