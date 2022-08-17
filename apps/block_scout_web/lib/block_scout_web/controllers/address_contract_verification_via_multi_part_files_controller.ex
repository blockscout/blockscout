defmodule BlockScoutWeb.AddressContractVerificationViaMultiPartFilesController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Controller
  alias Explorer.Chain
  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.{CompilerVersion, Solidity.CodeCompiler}

  def new(conn, %{"address_id" => address_hash_string}) do
    if Chain.smart_contract_fully_verified?(address_hash_string) do
      address_contract_path =
        conn
        |> address_contract_path(:index, address_hash_string)
        |> Controller.full_path()

      redirect(conn, to: address_contract_path)
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
        evm_versions: CodeCompiler.allowed_evm_versions(),
        compiler_versions: compiler_versions
      )
    end
  end
end
