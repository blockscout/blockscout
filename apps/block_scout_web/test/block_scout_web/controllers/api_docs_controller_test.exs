defmodule BlockScoutWeb.APIDocsControllerTest do
  use BlockScoutWeb.ConnCase

  import BlockScoutWeb.Router.Helpers, only: [api_docs_path: 2]

  describe "GET index/2" do
    test "renders documentation tiles for each API module#action", %{conn: conn} do
      conn = get(conn, api_docs_path(BlockScoutWeb.Endpoint, :index))

      documentation = BlockScoutWeb.Etherscan.get_documentation()

      for module <- documentation, action <- module.actions do
        assert html_response(conn, 200) =~ action.name
        assert html_response(conn, 200) =~ action.description
      end
    end
  end
end
