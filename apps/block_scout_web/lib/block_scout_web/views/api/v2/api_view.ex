defmodule BlockScoutWeb.API.V2.ApiView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.ErrorHelper

  def render("message.json", %{message: message}) do
    %{
      "message" => message
    }
  end

  def render("changeset_errors.json", %{changeset: changeset}) do
    %{
      "errors" => ErrorHelper.changeset_to_errors(changeset),
      "message" => "Error on inserting audit report"
    }
  end
end
