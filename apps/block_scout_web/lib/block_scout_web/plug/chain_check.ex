defmodule BlockScoutWeb.Plug.ChainCheck do
  @moduledoc """
  """

  alias Plug.Conn
  alias Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    IO.puts("chaincheck")
    IO.puts("#{inspect(conn)}")
  end
end
