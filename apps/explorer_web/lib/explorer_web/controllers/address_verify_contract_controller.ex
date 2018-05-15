defmodule ExplorerWeb.AddressVerifyContractController do
  use ExplorerWeb, :controller

  alias Explorer.Chain
  alias Explorer.SmartContract.Solidity.CompilerVersion

  def new(conn, %{"address_id" => address_hash_string}) do
    {:ok, hash} = Chain.string_to_address_hash(address_hash_string)
    {:ok, address} = Chain.hash_to_address(hash)

    changeset = Chain.Address.changeset(%Chain.Address{}, %{})

    {:ok, compiler_versions} = CompilerVersion.fetch_versions()

    render(conn, "new.html",
           address: address,
           changeset: changeset,
           compiler_versions: compiler_versions)
  end

  def create(_conn, _params) do
  end
end
