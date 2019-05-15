defmodule BlockScoutWeb.API.RPC.EthRPCView do
  use BlockScoutWeb, :view

  def render("show.json", %{result: result, id: id}) do
    %{
      "jsonrpc" => "2.0",
      "result" => result,
      "id" => id
    }
  end

  def render("error.json", %{error: message, id: id}) do
    %{
      "jsonrpc" => "2.0",
      "error" => message,
      "id" => id
    }
  end
end
