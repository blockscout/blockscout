# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.Legacy.EthController do
  @moduledoc """
  Thin OpenAPI-documented wrappers for individual JSON-RPC methods that are
  otherwise reachable only via the dispatch-by-`method` endpoint `/api/eth-rpc`.

  Each action:

    * accepts a JSON-RPC 2.0 single-object body (batch arrays are rejected),
    * validates that the body's `method` field matches the action's pinned
      method name and otherwise renders a JSON-RPC error envelope with the
      same `id`,
    * delegates to `BlockScoutWeb.API.EthRPC.EthController.eth_request/2`,
      which performs the actual work and renders via `EthRPCView`.

  Behavioral divergence from `/api/eth-rpc` worth noting:

    * the legacy endpoints run on the `:api_v2` pipeline, so when API v2 is
      globally disabled the legacy routes return 404 while `/api/eth-rpc` keeps
      working;
    * batches are not supported here — POST an array body and the endpoint
      returns a JSON-RPC error envelope rather than dispatching the batch.
  """

  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias BlockScoutWeb.API.EthRPC.EthController, as: V1EthController
  alias BlockScoutWeb.API.EthRPC.View, as: EthRPCView
  alias BlockScoutWeb.Schemas.API.Legacy.{Envelope, EthBlockNumberResult}
  alias BlockScoutWeb.Schemas.API.V2.General

  alias BlockScoutWeb.Schemas.API.Legacy.EthRpc.{
    EthCallResult,
    EthGetBalanceResult,
    EthGetLogsResult,
    EthGetStorageAtResult,
    EthSendRawTransactionResult,
    Requests
  }

  tags(["legacy"])

  operation :eth_call,
    summary: "Execute a contract call (eth_call)",
    description: """
    Performs a read-only EVM call against the given contract at the given block,
    without creating a transaction or modifying chain state — useful for
    querying contract data without spending gas.
    """,
    parameters: General.base_params(),
    request_body: Requests.eth_call(),
    responses: [
      ok:
        {"JSON-RPC 2.0 envelope (success or error; HTTP 200 regardless).", "application/json",
         Envelope.eth_rpc_envelope(EthCallResult)}
    ]

  @spec eth_call(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def eth_call(conn, params), do: dispatch(conn, params, "eth_call")

  operation :eth_get_balance,
    summary: "Get an address balance (eth_getBalance)",
    description: """
    Returns the wei balance of the given address at the given block.
    """,
    parameters: General.base_params(),
    request_body: Requests.eth_get_balance(),
    responses: [
      ok:
        {"JSON-RPC 2.0 envelope (success or error; HTTP 200 regardless).", "application/json",
         Envelope.eth_rpc_envelope(EthGetBalanceResult)}
    ]

  @spec eth_get_balance(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def eth_get_balance(conn, params), do: dispatch(conn, params, "eth_getBalance")

  operation :eth_get_storage_at,
    summary: "Read contract storage (eth_getStorageAt)",
    description: """
    Returns the raw storage value at the given slot of the given contract
    address at the given block.
    """,
    parameters: General.base_params(),
    request_body: Requests.eth_get_storage_at(),
    responses: [
      ok:
        {"JSON-RPC 2.0 envelope (success or error; HTTP 200 regardless).", "application/json",
         Envelope.eth_rpc_envelope(EthGetStorageAtResult)}
    ]

  @spec eth_get_storage_at(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def eth_get_storage_at(conn, params), do: dispatch(conn, params, "eth_getStorageAt")

  operation :eth_send_raw_transaction,
    summary: "Submit a signed transaction (eth_sendRawTransaction)",
    description: """
    Submits a pre-signed transaction to the underlying JSON-RPC node for
    inclusion in the mempool, and returns the transaction hash on acceptance.
    """,
    parameters: General.base_params(),
    request_body: Requests.eth_send_raw_transaction(),
    responses: [
      ok:
        {"JSON-RPC 2.0 envelope (success or error; HTTP 200 regardless).", "application/json",
         Envelope.eth_rpc_envelope(EthSendRawTransactionResult)}
    ]

  @spec eth_send_raw_transaction(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def eth_send_raw_transaction(conn, params), do: dispatch(conn, params, "eth_sendRawTransaction")

  operation :eth_block_number,
    summary: "Get the latest block number (eth_blockNumber)",
    description: """
    Returns the latest block number as a hex-encoded string in a JSON-RPC 2.0 response.
    """,
    parameters: General.base_params(),
    request_body: Requests.eth_block_number(),
    responses: [
      ok:
        {"JSON-RPC 2.0 envelope (success or error; HTTP 200 regardless).", "application/json",
         Envelope.eth_rpc_envelope(EthBlockNumberResult)}
    ]

  @spec eth_block_number(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def eth_block_number(conn, params), do: dispatch(conn, params, "eth_blockNumber")

  operation :eth_get_logs,
    summary: "Get event logs (eth_getLogs)",
    description: """
    Returns event logs matching the supplied filter object, in JSON-RPC 2.0 format.
    Up to a maximum of 1,000 log entries are returned per request.
    """,
    parameters: General.base_params(),
    request_body: Requests.eth_get_logs(),
    responses: [
      ok:
        {"JSON-RPC 2.0 envelope (success or error; HTTP 200 regardless).", "application/json",
         Envelope.eth_rpc_envelope(%OpenApiSpex.Schema{type: :array, items: EthGetLogsResult, nullable: true})}
    ]

  @spec eth_get_logs(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def eth_get_logs(conn, params), do: dispatch(conn, params, "eth_getLogs")

  @spec dispatch(Plug.Conn.t(), map(), String.t()) :: Plug.Conn.t()
  defp dispatch(conn, params, expected_method) do
    cond do
      batch?(params) ->
        render_jsonrpc_error(
          conn,
          "Batch requests are not supported on this endpoint",
          extract_id(params)
        )

      not method_matches?(params, expected_method) ->
        render_jsonrpc_error(
          conn,
          "`method` must be `#{expected_method}` for this endpoint",
          extract_id(params)
        )

      true ->
        V1EthController.eth_request(conn, params)
    end
  end

  defp batch?(%{"_json" => list}) when is_list(list), do: true
  defp batch?(_), do: false

  defp method_matches?(%{"method" => method}, expected) when is_binary(method), do: method == expected
  defp method_matches?(_, _), do: false

  defp extract_id(%{"id" => id}) when is_integer(id) or is_binary(id) or is_nil(id), do: id
  defp extract_id(_), do: 0

  defp render_jsonrpc_error(conn, message, id) do
    conn
    |> put_status(200)
    |> put_view(EthRPCView)
    |> render("error.json", %{error: message, id: id})
  end
end
