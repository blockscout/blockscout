defmodule BlockScoutWeb.MakerdojoView do
  use BlockScoutWeb, :view

  @dialyzer :no_match

  def get_url(list, page) do
    {:ok, response} = Jason.decode(list)
    Map.get(response, page)
  end
end
