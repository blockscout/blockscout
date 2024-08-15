defmodule BlockScoutWeb.API.V2.Proxy.MetadataView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.AddressView

  def render("addresses.json", %{result: {:ok, %{"addresses" => addresses} = body}}) do
    Map.put(body, "addresses", Enum.map(addresses, &AddressView.prepare_address/1))
  end

  def render("addresses.json", %{result: :error}) do
    %{error: "Decoding error"}
  end
end
