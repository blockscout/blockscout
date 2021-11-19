defmodule BlockScoutWeb.AddressContractVerificationViaStandardJsonInputController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AddressContractVerificationController, as: VerificationController
  alias BlockScoutWeb.Controller
  alias Explorer.Chain
  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.CompilerVersion
  alias Explorer.ThirdPartyIntegrations.Sourcify

  def new(conn, %{"address_id" => address_hash_string}) do
    if Chain.smart_contract_fully_verified?(address_hash_string) do
      address_path =
        conn
        |> address_path(:show, address_hash_string)
        |> Controller.full_path()
      redirect(conn, to: address_path)
    else
      changeset =
            SmartContract.changeset(
              %SmartContract{address_hash: address_hash_string},
              %{}
            )

      compiler_versions =
        case CompilerVersion.fetch_versions(:solc) do
          {:ok, compiler_versions} ->
            compiler_versions

          {:error, _} ->
            []
        end

      render(conn, "new.html",
        changeset: changeset,
        address_hash: address_hash_string,
        compiler_versions: compiler_versions)
    end
  end
end
