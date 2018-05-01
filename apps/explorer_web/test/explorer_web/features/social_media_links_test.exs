defmodule ExplorerWeb.SocialMediaLinksTest do
  use ExplorerWeb.FeatureCase, async: true

  import Wallaby.Query

  test "it shows twitter when twitter is configured", %{session: session} do
    Application.put_env(:explorer_web, ExplorerWeb.SocialMedia, twitter: "https://twitter.com/twitter")

    session
    |> visit("/")
    |> assert_has(css("[data-test='twitter_link']"))
  end

  test "it hides twitter when twitter is not configured", %{session: session} do
    Application.put_env(:explorer_web, ExplorerWeb.SocialMedia, facebook: "https://facebook.com/")

    session
    |> visit("/")
    |> refute_has(css("[data-test='twitter_link']"))
  end
end
