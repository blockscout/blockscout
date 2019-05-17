defmodule BlockScoutWeb.CommonComponentsView do
  use BlockScoutWeb, :view

  def add_page_size(base_path, number) do
    base_path <> "&page_size=#{number}"
  end
end
