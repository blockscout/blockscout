defmodule BlockScoutWeb.AddressContractVerificationViaJsonController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain.SmartContract

  def new(conn, %{"address_id" => address_hash_string}) do
    changeset =
      SmartContract.changeset(
        %SmartContract{address_hash: address_hash_string},
        %{}
      )

    render(conn, "new.html", changeset: changeset, address_hash: address_hash_string)
  end
end
