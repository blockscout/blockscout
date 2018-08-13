defmodule ExplorerWeb.LayoutView do
  use ExplorerWeb, :view

  alias ExplorerWeb.SocialMedia

  def configured_social_media_services do
    SocialMedia.links()
  end
end
