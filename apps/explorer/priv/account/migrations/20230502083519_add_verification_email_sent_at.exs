defmodule Explorer.Repo.Account.Migrations.AddVerificationEmailSentAt do
  use Ecto.Migration

  def change do
    alter table(:account_identities) do
      add(:verification_email_sent_at, :"timestamp without time zone", null: true)
    end
  end
end
