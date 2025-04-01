defmodule BlockScoutWeb.API.V2.ValidatorController do
  use BlockScoutWeb, :controller

  import Explorer.PagingOptions, only: [default_paging_options: 0]

  alias BlockScoutWeb.API.V2.ApiView
  alias Explorer.Chain.Blackfort.Validator, as: ValidatorBlackfort
  alias Explorer.Chain.Cache.Counters.{Blackfort, Stability}
  alias Explorer.Chain.Stability.Validator, as: ValidatorStability
  alias Explorer.Chain.Zilliqa.Hash.BLSPublicKey
  alias Explorer.Chain.Zilliqa.Staker, as: ValidatorZilliqa
  alias Explorer.Helper

  import BlockScoutWeb.PagingHelper,
    only: [
      delete_parameters_from_next_page_params: 1,
      stability_validators_state_options: 1,
      validators_blackfort_sorting: 1,
      validators_stability_sorting: 1
    ]

  import BlockScoutWeb.Chain,
    only: [
      split_list_by_page: 1,
      paging_options: 1,
      next_page_params: 4
    ]

  @api_true api?: true

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

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
        delete_parameters_from_next_page_params(params),
        &ValidatorStability.next_page_params/1
      )

    conn
    |> render(:stability_validators, %{validators: validators, next_page_params: next_page_params})
  end

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
      # todo: It should be removed in favour `validators_count` property with the next release after 8.0.0
      validators_counter: validators_counter,
      new_validators_count_24h: new_validators_counter,
      # todo: It should be removed in favour `new_validators_count_24h` property with the next release after 8.0.0
      new_validators_counter_24h: new_validators_counter,
      active_validators_count: active_validators_counter,
      # todo: It should be removed in favour `active_validators_count` property with the next release after 8.0.0
      active_validators_counter: active_validators_counter,
      active_validators_percentage:
        calculate_active_validators_percentage(active_validators_counter, validators_counter)
    })
  end

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
        delete_parameters_from_next_page_params(params),
        &ValidatorBlackfort.next_page_params/1
      )

    conn
    |> render(:blackfort_validators, %{validators: validators, next_page_params: next_page_params})
  end

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
      # todo: It should be removed in favour `validators_count` property with the next release after 8.0.0
      validators_counter: validators_counter,
      new_validators_count_24h: new_validators_counter,
      # todo: It should be removed in favour `new_validators_count_24h` property with the next release after 8.0.0
      new_validators_counter_24h: new_validators_counter
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

  @doc """
  Function to handle GET requests to `/api/v2/validators/zilliqa` endpoint.
  """
  @spec zilliqa_validators_list(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def zilliqa_validators_list(conn, params) do
    paging_options =
      with {:ok, index} <- Map.fetch(params, "index"),
           {:ok, index} <- Helper.safe_parse_non_negative_integer(index) do
        %{default_paging_options() | key: %{index: index}}
      else
        _ -> default_paging_options()
      end

    sorting_options =
      case params do
        %{"sort" => "index", "order" => "asc"} -> [asc_nulls_first: :index]
        %{"sort" => "index", "order" => "desc"} -> [desc_nulls_last: :index]
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
        delete_parameters_from_next_page_params(params),
        &ValidatorZilliqa.next_page_params/1
      )

    conn
    |> render(:zilliqa_validators, %{
      validators: validators,
      next_page_params: next_page_params
    })
  end

  @doc """
  Function to handle GET requests to `/api/v2/validators/zilliqa/:bls_public_key` endpoint.
  """
  @spec zilliqa_validator(Plug.Conn.t(), map()) :: Plug.Conn.t() | :error | {:error, :not_found}
  def zilliqa_validator(conn, %{"bls_public_key" => bls_public_key_string}) do
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
