defmodule BlockScoutWeb.API.RPC.EthRPCView do
  use BlockScoutWeb, :view

  def render("show.json", %{result: result, id: id}) do
    %{
      "id" => id,
      "jsonrpc" => "2.0",
      "result" => result
    }
  end

  def render("error.json", %{error: message, id: id}) do
    %{
      "id" => id,
      "jsonrpc" => "2.0",
      "error" => message
    }
  end
end
