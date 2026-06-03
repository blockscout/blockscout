# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.Legacy.BlockController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  # aliased with as: to avoid shadowing this module's own name
  # (BlockScoutWeb.API.V2.Legacy.BlockController)
  alias BlockScoutWeb.API.RPC.BlockController, as: V1BlockController
  alias BlockScoutWeb.Schemas.API.Legacy.{Envelope, GetBlockNumberByTimeResult}
  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.{Parameter, Schema}

  tags(["legacy"])

  operation :get_block_number_by_time,
    summary: "Get block number by time stamp",
    description: """
    Returns the block number created closest to a provided timestamp.

    Required:
    - `timestamp`
    - `closest`
    """,
    parameters:
      [
        %Parameter{
          name: :timestamp,
          in: :query,
          schema: General.IntegerString,
          description: "Unix timestamp in seconds."
        },
        %Parameter{
          name: :closest,
          in: :query,
          schema: %Schema{type: :string, enum: ["before", "after"]},
          description: "Whether to return the block before or after the timestamp."
        }
      ] ++ General.base_params(),
    responses: [
      ok: {"Block number", "application/json", Envelope.rpc_envelope(GetBlockNumberByTimeResult)}
    ]

  @doc """
  Thin bridge to the v1 `getblocknobytime` action at `/api?module=block&action=getblocknobytime`.
  """
  @spec get_block_number_by_time(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_block_number_by_time(conn, params), do: V1BlockController.getblocknobytime(conn, params)
end
