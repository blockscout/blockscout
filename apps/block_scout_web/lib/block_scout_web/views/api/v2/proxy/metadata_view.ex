defmodule BlockScoutWeb.API.V2.Proxy.MetadataView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.AddressView

  def render("addresses.json", %{result: {:ok, %{"items" => addresses} = body}}) do
    Map.put(body, "items", Enum.map(addresses, &AddressView.prepare_address_for_list/1))
  end

  def render("addresses.json", %{result: :error}) do
    %{error: "Decoding error"}
  end
end
