defmodule BlockScoutWeb.TestHelper do
  @moduledoc false
  use BlockScoutWeb.ConnCase

  def assert_block_above_tip(conn) do
    assert conn
           |> html_response(404)
           |> Floki.parse_fragment()
           |> elem(1)
           |> Floki.find(~S|.error-descr|)
           |> Floki.text()
           |> String.trim() == "Easy Cowboy! This block does not exist yet!"
  end
end
