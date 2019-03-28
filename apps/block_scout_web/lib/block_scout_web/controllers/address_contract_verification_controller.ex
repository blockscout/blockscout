defmodule BlockScoutWeb.AddressContractVerificationController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.{Publisher, Solidity.CodeCompiler, Solidity.CompilerVersion}

  @evm_versions ["homestead", "tangerineWhistle", "spuriousDragon", "byzantium", "constantinople"]

  def new(conn, %{"address_id" => address_hash_string}) do
    changeset =
      SmartContract.changeset(
        %SmartContract{address_hash: address_hash_string},
        %{}
      )

    {:ok, compiler_versions} = CompilerVersion.fetch_versions()

    render(conn, "new.html",
      changeset: changeset,
      compiler_versions: compiler_versions,
      evm_versions: CodeCompiler.allowed_evm_versions()
    )
  end

  def create(
        conn,
        %{
          "address_id" => address_hash_string,
          "smart_contract" => smart_contract,
          "external_libraries" => external_libraries,
          "evm_version" => evm_version
        }
      ) do
    smart_sontact_with_evm_version = Map.put(smart_contract, "evm_version", evm_version["evm_version"])

    case Publisher.publish(address_hash_string, smart_sontact_with_evm_version, external_libraries) do
      {:ok, _smart_contract} ->
        redirect(conn, to: address_contract_path(conn, :index, address_hash_string))

      {:error, changeset} ->
        {:ok, compiler_versions} = CompilerVersion.fetch_versions()

        render(conn, "new.html",
          changeset: changeset,
          compiler_versions: compiler_versions,
          evm_versions: CodeCompiler.allowed_evm_versions()
        )
    end
  end
end
