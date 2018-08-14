defmodule BlockScoutWeb.LayoutView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.SocialMedia

  def configured_social_media_services do
    SocialMedia.links()
  end
end
