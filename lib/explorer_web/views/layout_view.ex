defmodule ExplorerWeb.LayoutView do
  use ExplorerWeb, :view

  def logo_image(conn, alt: alt, class: class) do
    conn
    |> static_path("/images/logo.svg")
    |> img_tag(class: class, alt: alt)
  end
end
