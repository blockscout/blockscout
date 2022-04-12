defmodule BlockScoutWeb.API.RPC.EthView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.EthRPCView

  def render("responses.json", %{responses: responses}) do
    EthRPCView.render("responses.json", %{responses: responses})
  end

  def render("response.json", %{response: response}) do
    EthRPCView.render("response.json", %{response: response})
  end
end
