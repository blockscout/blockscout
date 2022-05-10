defmodule BlockScoutWeb.Account.CustomABIController do
  use BlockScoutWeb, :controller

  alias Ecto.Changeset
  alias Explorer.Account.CustomABI

  import BlockScoutWeb.Account.AuthController, only: [authenticate!: 1]

  def new(conn, _params) do
    authenticate!(conn)

    render(conn, "form.html", method: :create, custom_abi: empty_custom_abi())
  end

  def create(conn, %{"custom_abi" => custom_abi}) do
    current_user = authenticate!(conn)

    case CustomABI.create_new_custom_abi(%CustomABI{}, %{
           name: custom_abi["name"],
           address_hash: custom_abi["address_hash"],
           abi: custom_abi["abi"],
           identity_id: current_user.id
         }) do
      {:ok, _} ->
        redirect(conn, to: custom_abi_path(conn, :index))

      {:error, invalid_custom_abi} ->
        render(conn, "form.html", method: :create, custom_abi: invalid_custom_abi)
    end
  end

  def create(conn, _) do
    redirect(conn, to: custom_abi_path(conn, :index))
  end

  def index(conn, _params) do
    current_user = authenticate!(conn)

    render(conn, "index.html", custom_abis: CustomABI.get_custom_abis_by_identity_id(current_user.id))
  end

  def edit(conn, %{"id" => id}) do
    current_user = authenticate!(conn)

    case CustomABI.get_custom_abi_by_id_and_identity_id(id, current_user.id) do
      nil ->
        not_found(conn)

      %CustomABI{} = custom_abi ->
        render(conn, "form.html", method: :update, custom_abi: CustomABI.changeset_without_constraints(custom_abi))
    end
  end

  def update(conn, %{"id" => id, "custom_abi" => %{"abi" => abi, "name" => name, "address_hash" => address_hash}}) do
    current_user = authenticate!(conn)

    case CustomABI.update_custom_abi(%{
           id: id,
           name: name,
           address_hash: address_hash,
           abi: abi,
           identity_id: current_user.id
         }) do
      %Changeset{} = custom_abi ->
        render(conn, "form.html", method: :update, custom_abi: custom_abi)

      _ ->
        redirect(conn, to: custom_abi_path(conn, :index))
    end
  end

  def update(conn, _) do
    authenticate!(conn)

    redirect(conn, to: custom_abi_path(conn, :index))
  end

  def delete(conn, %{"id" => id}) do
    current_user = authenticate!(conn)

    CustomABI.delete_custom_abi(current_user.id, id)

    redirect(conn, to: custom_abi_path(conn, :index))
  end

  defp empty_custom_abi, do: CustomABI.changeset_without_constraints()
end
