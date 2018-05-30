defmodule ExplorerWeb.API.RPC.RPCView do
  use ExplorerWeb, :view

  def render("show.json", %{data: data}) do
    %{
      "status" => "1",
      "message" => "OK",
      "result" => data
    }
  end

  def render("error.json", %{error: message}) do
    %{
      "status" => "0",
      "message" => message,
      "result" => nil
    }
  end
end
