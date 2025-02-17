defmodule BlockScoutWeb.Account.API.V2.AccountView do
  def render("message.json", %{message: message}) do
    %{
      "message" => message
    }
  end
end
