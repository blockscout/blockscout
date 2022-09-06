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

  # sobelow_skip ["Traversal.FileModule"]
  def create(
        conn,
        %{
          "smart_contract" => smart_contract,
          "file" => files
        }
      ) do
    files_array = prepare_files_array(files)

    with %Plug.Upload{path: path} <- get_one_json(files_array),
         {:ok, json_input} <- File.read(path) do
      Que.add(SolidityPublisherWorker, {smart_contract, json_input, conn})
    else
      _ ->
        nil
    end

    send_resp(conn, 204, "")
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
        redirect(conn, to: "/address/#{smart_contract["address_hash"]}/verify-via-json/new")
      end
    else
      redirect(conn, to: "/address/#{smart_contract["address_hash"]}/verify-vyper-contract/new")
    end
  end

  def prepare_files_array(files) do
    if is_map(files), do: Enum.map(files, fn {_, file} -> file end), else: []
  end

  defp get_one_json(files_array) do
    files_array
    |> Enum.filter(fn file -> file.content_type == "application/json" end)
    |> Enum.at(0)
  end
end
