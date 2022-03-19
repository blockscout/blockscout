defmodule BlockScoutWeb.Account.TagTransactionController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Account.AuthController
  alias Ecto.Changeset
  alias Explorer.Accounts.TagTransaction
  alias Explorer.Repo

  import BlockScoutWeb.Account.AuthController, only: [authenticate!: 1]

  def index(conn, _params) do
    case AuthController.current_user(conn) do
      nil ->
        conn
        # |> put_flash(:info, "Sign in to see tx tags")
        |> redirect(to: root())

      %{} = user ->
        render(
          conn,
          "index.html",
          tx_tags: tx_tags(user)
        )
    end
  end

  def new(conn, _params) do
    authenticate!(conn)

    render(conn, "new.html", new_tag: new_tag())
  end

  def create(conn, %{"tag_transaction" => params}) do
    current_user = authenticate!(conn)

    case AddTagTransaction.call(current_user.id, params) do
      {:ok, _tag_tx} ->
        conn
        # |> put_flash(:info, "Tag Transaction created!")
        |> redirect(to: tag_transaction_path(conn, :index))

      {:error, message = message} ->
        conn
        # |> put_flash(:error, message)
        |> render("new.html", new_tag: changeset_with_error(params, message))
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = authenticate!(conn)

    TagTransaction
    |> Repo.get_by(id: id, identity_id: current_user.id)
    |> Repo.delete()

    conn
    # |> put_flash(:info, "Tag transaction removed successfully.")
    |> redirect(to: tag_transaction_path(conn, :index))
  end

  def tx_tags(user) do
    TagTransaction
    |> Repo.all(identity_id: user.id)
    |> Repo.preload(:transaction)
  end

  defp new_tag, do: TagTransaction.changeset(%TagTransaction{}, %{})

  defp changeset_with_error(params, message) do
    %{changeset(params) | action: :insert}
    |> Changeset.add_error(:tx_hash, message)
  end

  defp changeset(params) do
    TagTransaction.changeset(%TagTransaction{}, params)
  end

  defp root do
    System.get_env("NETWORK_PATH") || "/"
  end
end
