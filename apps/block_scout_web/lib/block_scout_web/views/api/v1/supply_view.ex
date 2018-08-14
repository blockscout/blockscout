defmodule BlockScoutWeb.API.V1.SupplyView do
  use BlockScoutWeb, :view

  def render("supply.json", %{total: total_supply, circulating: circulating_supply}) do
    %{
      "total_supply" => total_supply,
      "circulating_supply" => circulating_supply
    }
  end
end
