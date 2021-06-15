defmodule Explorer.Validator.MetadataImporter do
  @moduledoc """
  module that upserts validator metadata from a list of maps
  """
  alias Explorer.Chain.Address
  alias Explorer.Repo

  import Ecto.Query, only: [from: 2]

  def import_metadata(metadata_maps) do
    # Enforce Name ShareLocks order (see docs: sharelocks.md)
    ordered_metadata_maps =
      metadata_maps
      |> Enum.filter(fn metadata ->
        String.trim(metadata.name) !== ""
      end)
      |> Enum.sort_by(&{&1.address_hash, &1.name})

    Repo.transaction(fn -> Enum.each(ordered_metadata_maps, &upsert_validator_metadata(&1)) end)
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
