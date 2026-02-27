defmodule BlockScoutWeb.API.V2.ValidatorController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import Explorer.PagingOptions, only: [default_paging_options: 0]

  alias BlockScoutWeb.API.V2.ApiView
  alias BlockScoutWeb.Schemas.API.V2.ErrorResponses.{BadRequestResponse, NotFoundResponse}
  alias Explorer.Chain.Blackfort.Validator, as: ValidatorBlackfort
  alias Explorer.Chain.Cache.Counters.{Blackfort, Stability}
  alias Explorer.Chain.Stability.Validator, as: ValidatorStability
  alias Explorer.Chain.Zilliqa.Hash.BLSPublicKey
  alias Explorer.Chain.Zilliqa.Staker, as: ValidatorZilliqa

  import BlockScoutWeb.PagingHelper,
    only: [
      stability_validators_state_options: 1,
      validators_blackfort_sorting: 1,
      validators_stability_sorting: 1
    ]

  import BlockScoutWeb.Chain,
    only: [
      split_list_by_page: 1,
      paging_options: 1,
      next_page_params: 5
    ]

  @api_true api?: true

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  operation :stability_validators_list, false

  @doc """
    Function to handle GET requests to `/api/v2/validators/stability` endpoint.
  """
  @spec stability_validators_list(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def stability_validators_list(conn, params) do
    options =
      [
        necessity_by_association: %{
          [address: [:names, :smart_contract, proxy_implementations_association()]] => :optional
        }
      ]
      |> Keyword.merge(@api_true)
      |> Keyword.merge(paging_options(params))
      |> Keyword.merge(validators_stability_sorting(params))
      |> Keyword.merge(stability_validators_state_options(params))

    {validators, next_page} = options |> ValidatorStability.get_paginated_validators() |> split_list_by_page()

    next_page_params =
      next_page
      |> next_page_params(
        validators,
        params,
        false,
        &ValidatorStability.next_page_params/1
      )

    conn
    |> render(:stability_validators, %{validators: validators, next_page_params: next_page_params})
  end

  operation :stability_validators_counters, false

  @doc """
    Function to handle GET requests to `/api/v2/validators/stability/counters` endpoint.
  """
  @spec stability_validators_counters(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def stability_validators_counters(conn, _params) do
    %{
      validators_counter: validators_counter,
      new_validators_counter: new_validators_counter,
      active_validators_counter: active_validators_counter
    } = Stability.ValidatorsCount.get_counters(@api_true)

    conn
    |> json(%{
      validators_count: validators_counter,
      new_validators_count_24h: new_validators_counter,
      active_validators_count: active_validators_counter,
      active_validators_percentage:
        calculate_active_validators_percentage(active_validators_counter, validators_counter)
    })
  end

  operation :blackfort_validators_list, false

  @doc """
    Function to handle GET requests to `/api/v2/validators/blackfort` endpoint.
  """
  @spec blackfort_validators_list(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def blackfort_validators_list(conn, params) do
    options =
      [
        necessity_by_association: %{
          [address: [:names, :smart_contract, proxy_implementations_association()]] => :optional
        }
      ]
      |> Keyword.merge(@api_true)
      |> Keyword.merge(paging_options(params))
      |> Keyword.merge(validators_blackfort_sorting(params))

    {validators, next_page} = options |> ValidatorBlackfort.get_paginated_validators() |> split_list_by_page()

    next_page_params =
      next_page
      |> next_page_params(
        validators,
        params,
        false,
        &ValidatorBlackfort.next_page_params/1
      )

    conn
    |> render(:blackfort_validators, %{validators: validators, next_page_params: next_page_params})
  end

  operation :blackfort_validators_counters, false

  @doc """
    Function to handle GET requests to `/api/v2/validators/blackfort/counters` endpoint.
  """
  @spec blackfort_validators_counters(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def blackfort_validators_counters(conn, _params) do
    %{
      validators_counter: validators_counter,
      new_validators_counter: new_validators_counter
    } = Blackfort.ValidatorsCount.get_counters(@api_true)

    conn
    |> json(%{
      validators_count: validators_counter,
      new_validators_count_24h: new_validators_counter
    })
  end

  defp calculate_active_validators_percentage(active_validators_counter, validators_counter) do
    if Decimal.compare(validators_counter, Decimal.new(0)) == :gt do
      active_validators_counter
      |> Decimal.div(validators_counter)
      |> Decimal.mult(100)
      |> Decimal.to_float()
      |> Float.floor(2)
    end
  end

  tags(["zilliqa"])

  operation :zilliqa_validators_list,
    summary: "Zilliqa validators list.",
    description: "Retrieves the list of Zilliqa validators.",
    parameters:
      base_params() ++
        define_paging_params(["index", "items_count"]) ++
        [
          %OpenApiSpex.Parameter{
            name: :sort,
            in: :query,
            schema: %OpenApiSpex.Schema{
              type: :string,
              enum: ["index"],
              nullable: false
            },
            required: false
          },
          %OpenApiSpex.Parameter{
            name: :order,
            in: :query,
            schema: %OpenApiSpex.Schema{
              type: :string,
              enum: ["asc", "desc"],
              nullable: false
            },
            required: false
          }
        ],
    responses: [
      ok:
        {"List of validators.", "application/json",
         paginated_response(
           items: Schemas.Zilliqa.Staker,
           next_page_params_example: %{
             "index" => 55,
             "items_count" => 50
           },
           title_prefix: "Validators"
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Function to handle GET requests to `/api/v2/validators/zilliqa` endpoint.
  """
  @spec zilliqa_validators_list(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def zilliqa_validators_list(conn, params) do
    paging_options =
      case Map.fetch(params, :index) do
        {:ok, index} -> %{default_paging_options() | key: %{index: index}}
        _ -> default_paging_options()
      end

    sorting_options =
      case params do
        %{sort: "index", order: "asc"} -> [asc_nulls_first: :index]
        %{sort: "index", order: "desc"} -> [desc_nulls_last: :index]
        _ -> []
      end

    options =
      @api_true
      |> Keyword.merge(paging_options: paging_options)
      |> Keyword.merge(sorting_options: sorting_options)

    {validators, next_page} =
      options
      |> ValidatorZilliqa.paginated_active_stakers()
      |> split_list_by_page()

    next_page_params =
      next_page
      |> next_page_params(
        validators,
        params,
        false,
        &ValidatorZilliqa.next_page_params/1
      )

    conn
    |> render(:zilliqa_validators, %{
      validators: validators,
      next_page_params: next_page_params
    })
  end

  operation :zilliqa_validator,
    summary: "Zilliqa validator by its BLS public key.",
    description: "Retrieves Zilliqa validator detailed info by the given BLS public key.",
    parameters: [
      %OpenApiSpex.Parameter{
        name: :bls_public_key,
        in: :path,
        schema: Schemas.General.HexString,
        required: true
      }
      | base_params()
    ],
    responses: [
      ok: {"Validator detailed info.", "application/json", Schemas.Zilliqa.Staker.Detailed},
      unprocessable_entity: JsonErrorResponse.response(),
      bad_request: BadRequestResponse.response(),
      not_found: NotFoundResponse.response()
    ]

  @doc """
  Function to handle GET requests to `/api/v2/validators/zilliqa/:bls_public_key` endpoint.
  """
  @spec zilliqa_validator(Plug.Conn.t(), map()) :: Plug.Conn.t() | :error | {:error, :not_found}
  def zilliqa_validator(conn, %{bls_public_key: bls_public_key_string}) do
    options =
      [
        necessity_by_association: %{
          [
            control_address: [:names, :smart_contract, proxy_implementations_association()],
            reward_address: [:names, :smart_contract, proxy_implementations_association()],
            signing_address: [:names, :smart_contract, proxy_implementations_association()]
          ] => :optional
        }
      ]
      |> Keyword.merge(@api_true)

    with {:ok, _bls_public_key} <- BLSPublicKey.cast(bls_public_key_string),
         {:ok, staker} <- ValidatorZilliqa.bls_public_key_to_staker(bls_public_key_string, options) do
      render(conn, :zilliqa_validator, %{validator: staker})
    else
      :error ->
        conn
        |> put_view(ApiView)
        |> put_status(:bad_request)
        |> render(:message, %{message: "Invalid bls public key"})

      error ->
        error
    end
  end
end
