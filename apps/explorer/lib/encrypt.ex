defmodule Mix.Tasks.Encrypt do
  @moduledoc "The encrypt mix task: `mix help encrypt`"
  use Mix.Task

  alias Ecto.Changeset
  alias Explorer.Account.{CustomABI, Identity, TagAddress, TagTransaction, WatchlistAddress, WatchlistNotification}
  alias Explorer.Repo.Account
  alias Mix.Task

  @shortdoc "Encrypt"
  def run(_) do
    Task.run("app.start")

    Identity
    |> Account.all()
    |> Enum.each(fn element ->
      element
      |> Changeset.change(%{
        encrypted_uid: element.uid,
        encrypted_email: element.email,
        encrypted_name: element.name,
        encrypted_nickname: element.nickname,
        encrypted_avatar: element.avatar,
        uid_hash: element.uid
      })
      |> Account.update!()
    end)

    TagAddress
    |> Account.all()
    |> Enum.each(fn element ->
      element
      |> Changeset.change(%{
        encrypted_name: element.name,
        encrypted_address_hash: element.address_hash,
        address_hash_hash: element.address_hash |> to_string() |> String.downcase()
      })
      |> Account.update!()
    end)

    TagTransaction
    |> Account.all()
    |> Enum.each(fn element ->
      element
      |> Changeset.change(%{
        encrypted_name: element.name,
        encrypted_tx_hash: element.tx_hash,
        tx_hash_hash: element.tx_hash |> to_string() |> String.downcase()
      })
      |> Account.update!()
    end)

    CustomABI
    |> Account.all()
    |> Enum.each(fn element ->
      element
      |> Changeset.change(%{
        encrypted_name: element.name,
        encrypted_address_hash: element.address_hash,
        address_hash_hash: element.address_hash |> to_string() |> String.downcase()
      })
      |> Account.update!()
    end)

    WatchlistAddress
    |> Account.all()
    |> Enum.each(fn element ->
      element
      |> Changeset.change(%{
        encrypted_name: element.name,
        encrypted_address_hash: element.address_hash,
        address_hash_hash: element.address_hash |> to_string() |> String.downcase()
      })
      |> Account.update!()
    end)

    WatchlistNotification
    |> Account.all()
    |> Enum.each(fn element ->
      element
      |> Changeset.change(%{
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
      |> Account.update!()
    end)
  end
end
