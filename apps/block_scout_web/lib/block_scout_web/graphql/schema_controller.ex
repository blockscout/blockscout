defmodule BlockScoutWeb.GraphQL.SchemaController do
  @moduledoc """
  Controller for serving the GraphQL schema in SDL format.
  """

  use BlockScoutWeb, :controller

  @graphql_schema BlockScoutWeb.GraphQL.Schema
                  |> Absinthe.Schema.to_sdl()

  @doc """
  The GraphQL schema in SDL format, pre-built at compile time to avoid runtime
  overhead.
  """
  def index(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, @graphql_schema)
  end
end
