defmodule ExplorerWeb.AddressContractVerificationController do
  use ExplorerWeb, :controller

  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.{Solidity.CompilerVersion, Publisher}

  def new(conn, %{"address_id" => address_hash_string}) do
    changeset =
      SmartContract.changeset(
        %SmartContract{address_hash: address_hash_string},
        %{}
      )

    {:ok, compiler_versions} = CompilerVersion.fetch_versions()

    render(conn, "new.html", changeset: changeset, compiler_versions: compiler_versions)
  end

  def create(conn, %{
        "address_id" => address_hash_string,
        "smart_contract" => smart_contract,
        "locale" => locale
      }) do
    case Publisher.publish(address_hash_string, smart_contract) do
      {:ok, _smart_contract} ->
        redirect(conn, to: address_transaction_path(conn, :index, locale, address_hash_string))

      {:error, changeset} ->
        {:ok, compiler_versions} = CompilerVersion.fetch_versions()

        render(conn, "new.html", changeset: changeset, compiler_versions: compiler_versions)
    end
  end
end
