defmodule Explorer.Validator.MetadataImporter do
  @moduledoc """
  module that upserts validator metadata from a list of maps
  """
  alias Explorer.Chain.Address
  alias Explorer.Repo

  import Ecto.Query

  def import_metadata(metadata_maps) do
    Repo.transaction(fn ->
      deactivate_old_validators(metadata_maps)
      Enum.each(metadata_maps, &upsert_validator_metadata(&1))
    end)
  end

  defp deactivate_old_validators(metadata_maps) do
    new_validators = Enum.map(metadata_maps, &Map.get(&1, :address_hash))

    Address.Name
    |> where([an], is_nil(an.metadata) == false and an.address_hash not in ^new_validators)
    |> select([:address_hash, :metadata])
    |> Repo.all()
    |> Enum.each(fn %{address_hash: address_hash, metadata: metadata} ->
      new_metadata = Map.put(metadata, "active", false)

      Address.Name
      |> where([an], an.address_hash == ^address_hash)
      |> update([an], set: [metadata: ^new_metadata])
      |> Repo.update_all([])
    end)
  end

  defp upsert_validator_metadata(validator_changeset) do
    case Repo.get_by(Address.Name, address_hash: validator_changeset.address_hash, primary: true) do
      nil ->
        %Address.Name{}
        |> Address.Name.changeset(validator_changeset)
        |> Repo.insert()

      _address_name ->
        query =
          from(an in Address.Name,
            update: [
              set: [
                name: ^validator_changeset.name,
                metadata: ^validator_changeset.metadata
              ]
            ],
            where: an.address_hash == ^validator_changeset.address_hash and an.primary == true
          )

        Repo.update_all(query, [])
    end
  end
end
