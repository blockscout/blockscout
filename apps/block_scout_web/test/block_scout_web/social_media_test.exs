defmodule BlockScoutWeb.SocialMediaTest do
  use Explorer.DataCase

  alias BlockScoutWeb.SocialMedia

  test "it filters out unsupported services" do
    Application.put_env(
      :block_scout_web,
      BlockScoutWeb.SocialMedia,
      twitter: "MyTwitterProfile",
      myspace: "MyAwesomeProfile"
    )

    links = SocialMedia.links()
    assert Keyword.has_key?(links, :twitter)
    refute Keyword.has_key?(links, :myspace)
  end

  test "it prepends the service url" do
    Application.put_env(:block_scout_web, BlockScoutWeb.SocialMedia, twitter: "MyTwitterProfile")

    links = SocialMedia.links()
    assert links[:twitter] == "https://www.x.com/MyTwitterProfile"
  end
end
