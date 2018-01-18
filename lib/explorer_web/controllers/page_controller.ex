defmodule ExplorerWeb.PageController do
  use ExplorerWeb, :controller
  import Ecto.Query
  alias Explorer.Block
  alias Explorer.Repo

  def index(conn, _params) do
    blocks = Block
      |> order_by(desc: :number)
      |> limit(5)
      |> Repo.all

    render(conn, "index.html", blocks: blocks)
  end
end
