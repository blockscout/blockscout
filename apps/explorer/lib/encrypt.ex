defmodule Mix.Tasks.Encrypt do
  @moduledoc "The encrypt mix task: `mix help encrypt`"
  use Mix.Task

  @shortdoc "Encrypt"
  def run(_) do
    Mix.Task.run("app.start")

    Explorer.Account.Identity
    |> Explorer.Repo.Account.all()
    |> Enum.map(fn element ->
      element
      |> Ecto.Changeset.change(%{
        encrypted_uid: element.uid,
        encrypted_email: element.email,
        encrypted_name: element.name,
        encrypted_nickname: element.nickname,
        encrypted_avatar: element.avatar,
        uid_hash: element.uid
      })
      |> Explorer.Repo.Account.update!()
    end)

    Explorer.Account.TagAddress
    |> Explorer.Repo.Account.all()
    |> Enum.map(fn element ->
      element
      |> Ecto.Changeset.change(%{
        encrypted_name: element.name,
        encrypted_address_hash: element.address_hash,
        address_hash_hash: element.address_hash |> to_string() |> String.downcase()
      })
      |> Explorer.Repo.Account.update!()
    end)

    Explorer.Account.TagTransaction
    |> Explorer.Repo.Account.all()
    |> Enum.map(fn element ->
      element
      |> Ecto.Changeset.change(%{
        encrypted_name: element.name,
        encrypted_tx_hash: element.tx_hash,
        tx_hash_hash: element.tx_hash |> to_string() |> String.downcase()
      })
      |> Explorer.Repo.Account.update!()
    end)

    Explorer.Account.CustomABI
    |> Explorer.Repo.Account.all()
    |> Enum.map(fn element ->
      element
      |> Ecto.Changeset.change(%{
        encrypted_name: element.name,
        encrypted_address_hash: element.address_hash,
        address_hash_hash: element.address_hash |> to_string() |> String.downcase()
      })
      |> Explorer.Repo.Account.update!()
    end)

    Explorer.Account.WatchlistAddress
    |> Explorer.Repo.Account.all()
    |> Enum.map(fn element ->
      element
      |> Ecto.Changeset.change(%{
        encrypted_name: element.name,
        encrypted_address_hash: element.address_hash,
        address_hash_hash: element.address_hash |> to_string() |> String.downcase()
      })
      |> Explorer.Repo.Account.update!()
    end)

    Explorer.Account.WatchlistNotification
    |> Explorer.Repo.Account.all()
    |> Enum.map(fn element ->
      element
      |> Ecto.Changeset.change(%{
        encrypted_name: element.name,
        encrypted_from_address_hash: element.from_address_hash,
        encrypted_to_address_hash: element.to_address_hash,
        encrypted_transaction_hash: element.transaction_hash,
        encrypted_subject: element.subject,
        from_address_hash_hash: element.from_address_hash |> to_string() |> String.downcase(),
        to_address_hash_hash: element.to_address_hash |> to_string() |> String.downcase(),
        transaction_hash_hash: element.transaction_hash |> to_string() |> String.downcase(),
        subject_hash: element.subject
      })
      |> Explorer.Repo.Account.update!()
    end)
  end
end
