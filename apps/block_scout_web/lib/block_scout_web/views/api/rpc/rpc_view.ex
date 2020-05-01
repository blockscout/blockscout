defmodule BlockScoutWeb.API.RPC.RPCView do
  use BlockScoutWeb, :view

  def render("show.json", %{data: data}) do
    %{
      "status" => "1",
      "message" => "OK",
      "result" => data
    }
  end

  def render("show_value.json", data) do
    {value, _} =
      data
      |> Decimal.to_string(:normal)
      |> Float.parse()

    value
  end

  def render("error.json", %{error: message} = assigns) do
    %{
      "status" => "0",
      "message" => message,
      "result" => Map.get(assigns, :data)
    }
  end
end
