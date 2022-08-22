defmodule Explorer.Repo.Migrations.UniqueTrackingRows do
  use Ecto.Migration

  def change do
    create(unique_index(:clabs_contract_event_trackings, [:smart_contract_id, :topic], name: :smart_contract_id_topic))
  end
end
