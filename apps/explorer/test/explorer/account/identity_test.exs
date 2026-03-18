defmodule Explorer.Account.IdentityTest do
  use Explorer.DataCase

  alias Explorer.Account.{Identity, Watchlist}
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

      user_data = Identity.find_or_create(auth)

      %{
        id: identity_id,
        email: "john@blockscout.com",
        uid: "github|666666"
      } = Identity |> first() |> Repo.account_repo().one()

      %{
        id: watchlist_id,
        identity_id: ^identity_id,
        name: "default"
      } = Watchlist |> first() |> Repo.account_repo().one()

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

      user_data = Identity.find_or_create(auth)

      %{
        id: identity_id,
        email: "john@blockscout.com",
        uid: "google-oauth2|666666"
      } = Identity |> first() |> Repo.account_repo().one()

      %{
        id: watchlist_id,
        identity_id: ^identity_id,
        name: "default"
      } = Watchlist |> first() |> Repo.account_repo().one()

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

  describe "update_nickname_changeset/2" do
    test "accepts valid nickname" do
      identity = %Identity{nickname: "old_nickname"}
      changeset = Identity.update_nickname_changeset(identity, %{nickname: "new_nickname"})

      assert changeset.valid?
      assert get_change(changeset, :nickname) == "new_nickname"
    end

    test "rejects nickname shorter than 3 characters" do
      identity = %Identity{}
      changeset = Identity.update_nickname_changeset(identity, %{nickname: "ab"})

      refute changeset.valid?
      assert %{nickname: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "rejects nickname longer than 50 characters" do
      identity = %Identity{}
      nickname = String.duplicate("a", 51)
      changeset = Identity.update_nickname_changeset(identity, %{nickname: nickname})

      refute changeset.valid?
      assert %{nickname: ["should be at most 50 character(s)"]} = errors_on(changeset)
    end

    test "rejects nickname with spaces" do
      identity = %Identity{}
      changeset = Identity.update_nickname_changeset(identity, %{nickname: "new nickname"})

      refute changeset.valid?
      assert %{nickname: ["has invalid format"]} = errors_on(changeset)
    end

    test "rejects nickname with special characters like @" do
      identity = %Identity{}
      changeset = Identity.update_nickname_changeset(identity, %{nickname: "new@nickname"})

      refute changeset.valid?
      assert %{nickname: ["has invalid format"]} = errors_on(changeset)
    end
    test "rejects duplicate nickname" do
      # UseRepo.account_repo().insert to create the first one since factory might not be loaded in all environments
      Repo.account_repo().insert!(%Identity{uid: "user1", email: "user1@example.com", nickname: "taken_nickname"})

      identity2 = %Identity{}
      changeset = Identity.update_nickname_changeset(identity2, %{nickname: "taken_nickname"})

      # Since it's a unique_constraint, we need to try to insert it to trigger the error if it was just unique_constraint
      # But unsafe_validate_unique handles it before insert.
      refute changeset.valid?
      assert %{nickname: ["has already been taken"]} = errors_on(changeset)
    end
  end
end
