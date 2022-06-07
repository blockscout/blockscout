defmodule Explorer.Repo.Migrations.AddAccountPublicTagsRequests do
  use Ecto.Migration

  def change do
    create table(:account_public_tags_requests) do
      add(:identity_id, references(:account_identities))
      add(:full_name, :string)
      add(:email, :string)
      add(:company, :string)
      add(:website, :string)
      add(:tags, :string)
      add(:addresses, :text)
      add(:description, :text)
      add(:additional_comment, :string)
      add(:request_type, :string)
      add(:is_owner, :boolean)
      add(:remove_reason, :text)
      add(:request_id, :string)

      timestamps()
    end
  end
end
