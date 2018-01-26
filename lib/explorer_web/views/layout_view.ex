defmodule ExplorerWeb.LayoutView do
  use ExplorerWeb, :view
  alias ExplorerWeb.Endpoint

  def logo_image(conn, alt: alt) do
    conn
    |> static_path("/images/logo.png")
    |> img_tag(class: "header__logo", alt: alt)
    |> link(to: Endpoint.url(), class: "header__logo-link")
  end
end
