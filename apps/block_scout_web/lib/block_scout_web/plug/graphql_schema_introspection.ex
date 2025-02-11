defmodule BlockScoutWeb.Plug.GraphQLSchemaIntrospection do
  import Plug.Conn
  alias Absinthe.Schema

  @introspection_json BlockScoutWeb.GraphQL.Schema
                      |> Schema.introspect()
                      |> (case do
                            {:ok, data} -> Jason.encode!(data)
                            {:error, _} -> raise "Failed to introspect schema"
                          end)

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.params["operationName"] do
      "IntrospectionQuery" ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, @introspection_json)
        |> halt()

      _ ->
        conn
    end
  end
end
