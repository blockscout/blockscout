defmodule BlockScoutWeb.Account.Api.V2.AccountView do
  def render("message.json", %{message: message}) do
    %{
      "message" => message
    }
  end
end
