defmodule BlockScoutWeb.Account.Api.V1.AccountView do
  def render("message.json", %{message: message}) do
    %{
      "message" => message
    }
  end
end
