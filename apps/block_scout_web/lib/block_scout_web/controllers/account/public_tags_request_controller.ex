defmodule BlockScoutWeb.Account.PublicTagsRequestController do
  use BlockScoutWeb, :controller

  alias Ecto.Changeset
  alias Explorer.Account.PublicTagsRequest

  import BlockScoutWeb.Account.AuthController, only: [authenticate!: 1]

  def index(conn, _params) do
    current_user = authenticate!(conn)

    render(conn, "index.html",
      public_tags_requests: PublicTagsRequest.get_public_tags_requests_by_identity_id(current_user.id)
    )
  end

  def new(conn, _params) do
    current_user = authenticate!(conn)

    render(conn, "form.html",
      method: :create,
      public_tags_request:
        PublicTagsRequest.changeset_without_constraints(%PublicTagsRequest{}, %{
          full_name: current_user.name,
          email: current_user.email
        })
    )
  end

  def create(conn, %{"public_tags_request" => public_tags_request}) do
    current_user = authenticate!(conn)

    case PublicTagsRequest.create(%{
           full_name: public_tags_request["full_name"],
           email: public_tags_request["email"],
           tags: public_tags_request["tags"],
           website: public_tags_request["website"],
           additional_comment: public_tags_request["additional_comment"],
           addresses_array: public_tags_request["addresses_array"],
           company: public_tags_request["company"],
           is_owner: public_tags_request["is_owner"],
           identity_id: current_user.id
         }) do
      {:ok, _} ->
        redirect(conn, to: public_tags_request_path(conn, :index))

      {:error, invalid_public_tags_request} ->
        render(conn, "form.html", method: :create, public_tags_request: invalid_public_tags_request)
    end
  end

  def create(conn, _) do
    redirect(conn, to: public_tags_request_path(conn, :index))
  end

  def edit(conn, %{"id" => id}) do
    current_user = authenticate!(conn)

    case PublicTagsRequest.get_public_tags_request_by_id_and_identity_id(id, current_user.id) do
      nil ->
        not_found(conn)

      %PublicTagsRequest{} = public_tags_request ->
        render(conn, "form.html",
          method: :update,
          public_tags_request: PublicTagsRequest.changeset_without_constraints(public_tags_request)
        )
    end
  end

  def update(conn, %{
        "id" => id,
        "public_tags_request" => public_tags_request
      }) do
    current_user = authenticate!(conn)

    case PublicTagsRequest.update(%{
           id: id,
           full_name: public_tags_request["full_name"],
           email: public_tags_request["email"],
           tags: public_tags_request["tags"],
           website: public_tags_request["website"],
           additional_comment: public_tags_request["additional_comment"],
           addresses_array: public_tags_request["addresses_array"],
           company: public_tags_request["company"],
           is_owner: public_tags_request["is_owner"],
           identity_id: current_user.id
         }) do
      {:error, %Changeset{}} = public_tags_request ->
        render(conn, "form.html", method: :update, public_tags_request: public_tags_request)

      _ ->
        redirect(conn, to: public_tags_request_path(conn, :index))
    end
  end

  def update(conn, _) do
    authenticate!(conn)

    redirect(conn, to: public_tags_request_path(conn, :index))
  end

  def delete(conn, %{"id" => id, "remove_reason" => remove_reason}) do
    current_user = authenticate!(conn)

    PublicTagsRequest.mark_as_deleted_public_tags_request(%{
      id: id,
      identity_id: current_user.id,
      remove_reason: remove_reason
    })

    redirect(conn, to: public_tags_request_path(conn, :index))
  end
end
