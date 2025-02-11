defmodule BlockScoutWeb.GraphQL.SchemaController do
  use BlockScoutWeb, :controller

  @graphql_schema BlockScoutWeb.GraphQL.Schema
                  |> Absinthe.Schema.to_sdl()

  def index(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, @graphql_schema)
  end
end
