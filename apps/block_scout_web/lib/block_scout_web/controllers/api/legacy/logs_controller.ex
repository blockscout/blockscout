defmodule BlockScoutWeb.API.Legacy.LogsController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias BlockScoutWeb.API.RPC.LogsController, as: V1LogsController
  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.API.Legacy.{Envelope, LogItem}
  alias OpenApiSpex.{Parameter, Schema}

  tags(["legacy"])

  @topic_schema %Schema{type: :string, pattern: ~r/^0x[0-9a-fA-F]{64}$/}
  @topic_opr_schema %Schema{type: :string, enum: ["and", "or"]}

  operation :get_logs,
    summary: "Get Event Logs by Address and/or Topic(s)",
    description: """
    Event logs for an address and topic. Use and/or with the topic operator to specify
    topic retrieval options when adding multiple topics. Up to a maximum of 1,000 event logs.

    Required:
    - `fromBlock` and `toBlock`
    - At least one of `address`, `topic0`, `topic1`, `topic2`, `topic3`
    - If any pair of topic parameters is set, the corresponding `topicA_B_opr` is required.
    """,
    parameters:
      [
        %Parameter{
          name: :fromBlock,
          in: :query,
          schema: %Schema{anyOf: [General.IntegerString, %Schema{type: :string, enum: ["latest"]}]},
          description: "Start block: integer or the sentinel \"latest\""
        },
        %Parameter{
          name: :toBlock,
          in: :query,
          schema: %Schema{anyOf: [General.IntegerString, %Schema{type: :string, enum: ["latest"]}]},
          description: "End block: integer or the sentinel \"latest\""
        },
        %Parameter{name: :address, in: :query, schema: General.AddressHash},
        %Parameter{name: :topic0, in: :query, schema: @topic_schema},
        %Parameter{name: :topic1, in: :query, schema: @topic_schema},
        %Parameter{name: :topic2, in: :query, schema: @topic_schema},
        %Parameter{name: :topic3, in: :query, schema: @topic_schema},
        %Parameter{name: :topic0_1_opr, in: :query, schema: @topic_opr_schema},
        %Parameter{name: :topic0_2_opr, in: :query, schema: @topic_opr_schema},
        %Parameter{name: :topic0_3_opr, in: :query, schema: @topic_opr_schema},
        %Parameter{name: :topic1_2_opr, in: :query, schema: @topic_opr_schema},
        %Parameter{name: :topic1_3_opr, in: :query, schema: @topic_opr_schema},
        %Parameter{name: :topic2_3_opr, in: :query, schema: @topic_opr_schema}
      ] ++ General.base_params(),
    responses: [
      ok:
        {"Event logs", "application/json", Envelope.rpc_envelope(%Schema{type: :array, items: LogItem, nullable: true})}
    ]

  @doc """
  Thin bridge to the v1 `getlogs` action at `/api?module=logs&action=getlogs`.
  """
  @spec get_logs(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_logs(conn, params), do: V1LogsController.getlogs(conn, params)
end
