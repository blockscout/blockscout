defmodule BlockScoutWeb.Account.TagAddressController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Account.AuthController
  alias Ecto.Changeset
  alias Explorer.Accounts.TagAddress
  alias Explorer.Repo

  import BlockScoutWeb.Account.AuthController, only: [authenticate!: 1]

  def index(conn, _params) do
    case AuthController.current_user(conn) do
      nil ->
        conn
        # |> put_flash(:info, "Sign in to see address tags")
        |> redirect(to: root())

      %{} = user ->
        render(
          conn,
          "index.html",
          address_tags: address_tags(user)
        )
    end
  end

  def new(conn, _params) do
    authenticate!(conn)

    render(conn, "new.html", new_tag: new_tag())
  end

  def create(conn, %{"tag_address" => params}) do
    current_user = authenticate!(conn)

    case AddTagAddress.call(current_user.id, params) do
      {:ok, _tag_address} ->
        conn
        # |> put_flash(:info, "Tag Address created!")
        |> redirect(to: tag_address_path(conn, :index))

      {:error, message = message} ->
        conn
        # |> put_flash(:error, message)
        |> render("new.html", new_tag: changeset_with_error(params, message))
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = authenticate!(conn)

    TagAddress
    |> Repo.get_by(id: id, identity_id: current_user.id)
    |> Repo.delete()

    conn
    # |> put_flash(:info, "Tag Address removed successfully.")
    |> redirect(to: tag_address_path(conn, :index))
  end

  def address_tags(user) do
    TagAddress
    |> Repo.all(identity_id: user.id)
    |> Repo.preload(:address)
  end

  defp new_tag, do: TagAddress.changeset(%TagAddress{}, %{})

  defp changeset_with_error(params, message) do
    %{changeset(params) | action: :insert}
    |> Changeset.add_error(:address_hash, message)
  end

  defp changeset(params) do
    TagAddress.changeset(%TagAddress{}, params)
  end

  defp root do
    System.get_env("NETWORK_PATH") || "/"
  end
end
