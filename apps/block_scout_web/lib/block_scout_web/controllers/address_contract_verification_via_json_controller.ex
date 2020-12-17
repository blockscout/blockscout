defmodule BlockScoutWeb.AddressContractVerificationViaJsonController do
  use BlockScoutWeb, :controller

  def new(conn, %{"address_id" => address_hash_string}) do
    render(conn, "new.html", address_hash: address_hash_string)
  end
end
