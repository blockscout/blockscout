defmodule BlockScoutWeb.AddressContractVerificationController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Controller
  alias Explorer.Chain
  alias Explorer.Chain.SmartContract

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

      render(conn, "new.html",
        changeset: changeset,
        address_hash: address_hash_string
      )
    end
  end

  def new(conn, _params) do
    changeset =
      %SmartContract{}
      |> SmartContract.changeset(%{})

    render(conn, "new.html",
      changeset: changeset,
      address_hash: ""
    )
  end

  def create(
        conn,
        %{"smart_contract" => smart_contract}
      ) do
    if smart_contract["verify_via"] == "true" do
      if Chain.smart_contract_verified?(smart_contract["address_hash"]) do
        address_path =
          conn
          |> address_path(:show, smart_contract["address_hash"])
          |> Controller.full_path()

        redirect(conn, to: address_path)
      else
        redirect(conn, to: "/address/#{smart_contract["address_hash"]}/verify-via-metadata-json/new")
      end
    else
      redirect(conn, to: "/address/#{smart_contract["address_hash"]}/verify-vyper-contract/new")
    end
  end
end
