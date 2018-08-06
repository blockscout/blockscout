defmodule ExplorerWeb.APIDocsControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [api_docs_path: 3]

  describe "GET index/2" do
    test "renders documentation tiles for each API module#action", %{conn: conn} do
      conn = get(conn, api_docs_path(ExplorerWeb.Endpoint, :index, :en))

      documentation = ExplorerWeb.Etherscan.get_documentation()

      for module <- documentation, action <- module.actions do
        assert html_response(conn, 200) =~ action.name
        assert html_response(conn, 200) =~ action.description
      end
    end
  end
end
