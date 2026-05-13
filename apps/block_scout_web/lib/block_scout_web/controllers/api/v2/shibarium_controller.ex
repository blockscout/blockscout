# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.V2.ShibariumController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1
    ]

  alias Explorer.Chain.Cache.Counters.Shibarium.DepositsAndWithdrawalsCount
  alias Explorer.Chain.Shibarium.Reader

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  tags(["shibarium"])

  @api_true [api?: true]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  operation :deposits,
    summary: "List Shibarium deposits.",
    description: """
    Retrieves a paginated list of completed Shibarium deposits ordered by parent chain block number descending.
    A deposit is "completed" when both the parent-chain and Shibarium sides of the bridge have been observed.
    """,
    # The `Enum.map` block below is mirrored in :withdrawals. The only delta is the `block_number`
    # description, so the block is duplicated intentionally rather than hidden behind a helper for
    # two call sites.
    parameters:
      base_params() ++
        Enum.map(
          define_paging_params(["block_number"]),
          fn
            %OpenApiSpex.Parameter{name: :block_number} = param ->
              %{param | description: "Parent chain block number for paging (cursor on `l1_block_number`)."}

            param ->
              param
          end
        ),
    responses: [
      ok:
        {"List of Shibarium deposits.", "application/json",
         paginated_response(
           items: Schemas.Shibarium.Deposit,
           next_page_params_example: %{
             "block_number" => 17_500_000
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @spec deposits(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deposits(conn, params) do
    {deposits, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Reader.deposits()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, deposits, params)

    conn
    |> put_status(200)
    |> render(:shibarium_deposits, %{
      deposits: deposits,
      next_page_params: next_page_params
    })
  end

  # The `%Schema{type: :integer, ...}` body below is mirrored in :withdrawals_count. The shape is a
  # one-line primitive, so the schema is inlined at each call site rather than extracted into a
  # shared leaf module that would only be referenced twice within this controller.
  operation :deposits_count,
    summary: "Number of Shibarium deposits.",
    description: "Retrieves the total count of completed Shibarium deposits.",
    parameters: base_params(),
    responses: [
      ok:
        {"Number of items in the deposits list.", "application/json",
         %Schema{type: :integer, nullable: false, minimum: 0}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @spec deposits_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deposits_count(conn, _params) do
    count =
      case @api_true |> DepositsAndWithdrawalsCount.deposits_count() |> Decimal.to_integer() do
        0 -> Reader.deposits_count(@api_true)
        value -> value
      end

    conn
    |> put_status(200)
    |> render(:shibarium_items_count, %{count: count})
  end

  operation :withdrawals,
    summary: "List Shibarium withdrawals.",
    description: """
    Retrieves a paginated list of completed Shibarium withdrawals ordered by Shibarium block number descending.
    A withdrawal is "completed" when both the Shibarium and parent-chain sides of the bridge have been observed.
    """,
    # The `Enum.map` block below is mirrored in :deposits. The only delta is the `block_number`
    # description, so the block is duplicated intentionally rather than hidden behind a helper for
    # two call sites.
    parameters:
      base_params() ++
        Enum.map(
          define_paging_params(["block_number"]),
          fn
            %OpenApiSpex.Parameter{name: :block_number} = param ->
              %{param | description: "Shibarium block number for paging (cursor on `l2_block_number`)."}

            param ->
              param
          end
        ),
    responses: [
      ok:
        {"List of Shibarium withdrawals.", "application/json",
         paginated_response(
           items: Schemas.Shibarium.Withdrawal,
           next_page_params_example: %{
             "block_number" => 5_000_000
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @spec withdrawals(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def withdrawals(conn, params) do
    {withdrawals, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Reader.withdrawals()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, withdrawals, params)

    conn
    |> put_status(200)
    |> render(:shibarium_withdrawals, %{
      withdrawals: withdrawals,
      next_page_params: next_page_params
    })
  end

  # The `%Schema{type: :integer, ...}` body below is mirrored in :deposits_count. The shape is a
  # one-line primitive, so the schema is inlined at each call site rather than extracted into a
  # shared leaf module that would only be referenced twice within this controller.
  operation :withdrawals_count,
    summary: "Number of Shibarium withdrawals.",
    description: "Retrieves the total count of completed Shibarium withdrawals.",
    parameters: base_params(),
    responses: [
      ok:
        {"Number of items in the withdrawals list.", "application/json",
         %Schema{type: :integer, nullable: false, minimum: 0}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @spec withdrawals_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def withdrawals_count(conn, _params) do
    count =
      case @api_true |> DepositsAndWithdrawalsCount.withdrawals_count() |> Decimal.to_integer() do
        0 -> Reader.withdrawals_count(@api_true)
        value -> value
      end

    conn
    |> put_status(200)
    |> render(:shibarium_items_count, %{count: count})
  end
end
