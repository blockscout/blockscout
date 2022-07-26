defmodule UserFromAuthTest do
  use Explorer.DataCase

  alias BlockScoutWeb.Models.UserFromAuth
  alias Explorer.Account.Identity
  alias Explorer.Account.Watchlist
  alias Explorer.Repo
  alias Ueberauth.Auth
  alias Ueberauth.Auth.Info
  alias Ueberauth.Strategy.Auth0

  describe "get user info" do
    test "from github" do
      auth = %Auth{
        info: %Info{
          birthday: nil,
          description: nil,
          email: "john@blockscout.com",
          first_name: nil,
          image: "https://avatars.githubusercontent.com/u/666666=4",
          last_name: nil,
          location: nil,
          name: "John Snow",
          nickname: "johnnny",
          phone: nil,
          urls: %{profile: nil, website: nil}
        },
        provider: :auth0,
        strategy: Auth0,
        uid: "github|666666"
      }

      user_data = UserFromAuth.find_or_create(auth)

      %{
        id: identity_id,
        email: "john@blockscout.com",
        name: "John Snow",
        uid: "github|666666"
      } = Identity |> first |> Repo.one()

      %{
        id: watchlist_id,
        identity_id: ^identity_id,
        name: "default"
      } = Watchlist |> first |> Repo.one()

      assert {:ok,
              %{
                avatar: "https://avatars.githubusercontent.com/u/666666=4",
                email: "john@blockscout.com",
                id: ^identity_id,
                name: "John Snow",
                nickname: "johnnny",
                uid: "github|666666",
                watchlist_id: ^watchlist_id
              }} = user_data
    end

    test "from google" do
      auth = %Auth{
        info: %Info{
          birthday: nil,
          description: nil,
          email: "john@blockscout.com",
          first_name: "John",
          image: "https://lh3.googleusercontent.com/a/xxx666-yyy777=s99-c",
          last_name: "Snow",
          location: nil,
          name: "John Snow",
          nickname: "johnnny",
          phone: nil,
          urls: %{profile: nil, website: nil}
        },
        provider: :auth0,
        strategy: Auth0,
        uid: "google-oauth2|666666"
      }

      user_data = UserFromAuth.find_or_create(auth)

      %{
        id: identity_id,
        email: "john@blockscout.com",
        name: "John Snow",
        uid: "google-oauth2|666666"
      } = Identity |> first |> Repo.one()

      %{
        id: watchlist_id,
        identity_id: ^identity_id,
        name: "default"
      } = Watchlist |> first |> Repo.one()

      assert {:ok,
              %{
                avatar: "https://lh3.googleusercontent.com/a/xxx666-yyy777=s99-c",
                email: "john@blockscout.com",
                id: ^identity_id,
                name: "John Snow",
                nickname: "johnnny",
                uid: "google-oauth2|666666",
                watchlist_id: ^watchlist_id
              }} = user_data
    end
  end
end
