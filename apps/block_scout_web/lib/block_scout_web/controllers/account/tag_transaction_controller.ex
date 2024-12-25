defmodule BlockScoutWeb.Account.TagTransactionController do
  use BlockScoutWeb, :controller

  alias Explorer.Account.TagTransaction

  import BlockScoutWeb.Account.AuthController, only: [authenticate!: 1]

  def index(conn, _params) do
    current_user = authenticate!(conn)

    render(conn, "index.html", transaction_tags: TagTransaction.get_tags_transaction_by_identity_id(current_user.id))
  end

  def new(conn, _params) do
    authenticate!(conn)

    render(conn, "form.html", tag_transaction: new_tag())
  end

  def create(conn, %{"tag_transaction" => tag_address}) do
    current_user = authenticate!(conn)

    case TagTransaction.create(%{
           name: tag_address["name"],
           transaction_hash: tag_address["transaction_hash"],
           identity_id: current_user.id
         }) do
      {:ok, _} ->
        redirect(conn, to: tag_transaction_path(conn, :index))

      {:error, invalid_tag_transaction} ->
        render(conn, "form.html", tag_transaction: invalid_tag_transaction)
    end
  end

  def create(conn, _) do
    redirect(conn, to: tag_transaction_path(conn, :index))
  end

  def delete(conn, %{"id" => id}) do
    current_user = authenticate!(conn)

    TagTransaction.delete(id, current_user.id)

    redirect(conn, to: tag_transaction_path(conn, :index))
  end

  defp new_tag, do: TagTransaction.changeset()
end
