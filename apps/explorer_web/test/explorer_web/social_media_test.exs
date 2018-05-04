defmodule ExplorerWeb.SocialMediaTest do
  use Explorer.DataCase

  alias ExplorerWeb.SocialMedia

  test "it filters out unsupported services" do
    Application.put_env(
      :explorer_web,
      ExplorerWeb.SocialMedia,
      twitter: "MyTwitterProfile",
      myspace: "MyAwesomeProfile"
    )

    links = SocialMedia.links()
    assert Keyword.has_key?(links, :twitter)
    refute Keyword.has_key?(links, :myspace)
  end

  test "it prepends the service url" do
    Application.put_env(:explorer_web, ExplorerWeb.SocialMedia, twitter: "MyTwitterProfile")

    links = SocialMedia.links()
    assert links[:twitter] == "https://www.twitter.com/MyTwitterProfile"
  end
end
