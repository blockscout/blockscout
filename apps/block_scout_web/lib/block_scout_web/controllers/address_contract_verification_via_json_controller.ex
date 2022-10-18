defmodule BlockScoutWeb.AddressContractVerificationViaJsonController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AddressContractVerificationController, as: VerificationController
  alias BlockScoutWeb.Controller
  alias Explorer.Chain
  alias Explorer.Chain.SmartContract
  alias Explorer.ThirdPartyIntegrations.Sourcify

  def new(conn, %{"address_id" => address_hash_string}) do
    address_contract_path =
      conn
      |> address_contract_path(:index, address_hash_string)
      |> Controller.full_path()

    if Chain.smart_contract_fully_verified?(address_hash_string) do
      redirect(conn, to: address_contract_path)
    else
      case Sourcify.check_by_address(address_hash_string) do
        {:ok, _verified_status} ->
          VerificationController.get_metadata_and_publish(address_hash_string, conn)
          redirect(conn, to: address_contract_path)

        _ ->
          changeset =
            SmartContract.changeset(
              %SmartContract{address_hash: address_hash_string},
              %{}
            )

          render(conn, "new.html", changeset: changeset, address_hash: address_hash_string)
      end
    end
  end
end
