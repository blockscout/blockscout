defmodule BlockScoutWeb.API.V2.ValidatorController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain.Blackfort.Validator, as: ValidatorBlackfort
  alias Explorer.Chain.Cache.{BlackfortValidatorsCounters, StabilityValidatorsCounters}
  alias Explorer.Chain.Stability.Validator, as: ValidatorStability

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

  @doc """
    Function to handle GET requests to `/api/v2/validators/stability` endpoint.
  """
  @spec stability_validators_list(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def stability_validators_list(conn, params) do
    options =
      [
        necessity_by_association: %{
          [address: [:names, :smart_contract, :proxy_implementations]] => :optional
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
    } = StabilityValidatorsCounters.get_counters(@api_true)

    conn
    |> json(%{
      validators_counter: validators_counter,
      new_validators_counter_24h: new_validators_counter,
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
          [address: [:names, :smart_contract, :proxy_implementations]] => :optional
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
    } = BlackfortValidatorsCounters.get_counters(@api_true)

    conn
    |> json(%{
      validators_counter: validators_counter,
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
end
