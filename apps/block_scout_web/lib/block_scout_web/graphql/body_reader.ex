defmodule BlockScoutWeb.GraphQL.BodyReader do
  @moduledoc """
  This module is responsible for reading the body of a graphql request and counting the number of queries in the body.
  """

  alias Plug.Conn

  @max_number_of_queries 1

  def read_body(conn, opts) do
    {:ok, body, conn} = Conn.read_body(conn, opts)
    updated_conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])

    json_body = Jason.decode!(body)

    json_body_length =
      if is_list(json_body) do
        Enum.count(json_body)
      else
        1
      end

    error = %{errors: [%{message: "Max batch size is 1"}]}

    if json_body_length > @max_number_of_queries do
      {:ok, "",
       updated_conn
       |> Conn.put_resp_content_type("application/json")
       |> Conn.resp(400, Jason.encode!(error))
       |> Conn.halt()}
    else
      {:ok, body, updated_conn}
    end
  end
end
