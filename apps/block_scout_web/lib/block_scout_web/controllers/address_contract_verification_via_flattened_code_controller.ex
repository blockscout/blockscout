defmodule BlockScoutWeb.AddressContractVerificationViaFlattenedCodeController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Controller
  alias Explorer.Chain
  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.{CompilerVersion, Solidity.CodeCompiler, Solidity.PublisherWorker}

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
        compiler_versions: compiler_versions,
        evm_versions: CodeCompiler.evm_versions(:solidity),
        address_hash: address_hash_string
      )
    end
  end

  def create(
        conn,
        %{
          "smart_contract" => smart_contract,
          "external_libraries" => external_libraries
        }
      ) do
    Que.add(PublisherWorker, {"flattened", smart_contract, external_libraries, conn})

    send_resp(conn, 204, "")
  end
end
