defmodule BlockScoutWeb.TestHelper do
  @moduledoc false
  use BlockScoutWeb.ConnCase

  @doc """
  Asserts that the connection response contains the "block above tip" error message.

  ## Parameters
  - `conn`: A Phoenix connection struct with a 404 response

  ## Returns
  - Assertion passes if the error message matches, raises otherwise
  """
  @spec assert_block_above_tip(Plug.Conn.t()) :: true
  def assert_block_above_tip(conn) do
    html = html_response(conn, 404)
    {:ok, document} = Floki.parse_fragment(html)
    [error_element | _] = Floki.find(document, ~S|.error-descr|)
    assert Floki.text(error_element) |> String.trim() == "Easy Cowboy! This block does not exist yet!"
  end
end
