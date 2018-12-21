defmodule Explorer.Validator.MetadataImporterTest do
  use Explorer.DataCase

  require Ecto.Query

  import Ecto.Query
  import Explorer.Factory

  alias Explorer.Chain.Address
  alias Explorer.Repo
  alias Explorer.Validator.MetadataImporter

  describe "import_metadata/1" do
    test "inserts new address names when there's none for the validators" do
      address = insert(:address)

      address_hash = address.hash

      [%{address_hash: address_hash, name: "Testinit Unitorius", primary: true, metadata: %{"test" => "toast"}}]
      |> MetadataImporter.import_metadata()

      address_names =
        from(an in Address.Name, where: an.address_hash == ^address_hash and an.primary == true)
        |> Repo.all()

      assert length(address_names) == 1

      assert %Address.Name{address_hash: ^address_hash, name: "Testinit Unitorius", metadata: %{"test" => "toast"}} =
               hd(address_names)
    end

    test "updates the primary address name if the validator already has one" do
      address = insert(:address)

      insert(:address_name, address: address, primary: true, name: "Nodealus Faileddi")

      address_hash = address.hash

      [%{address_hash: address_hash, name: "Testit Unitorus", primary: true, metadata: %{"test" => "toast"}}]
      |> MetadataImporter.import_metadata()

      address_names =
        from(an in Address.Name, where: an.address_hash == ^address.hash and an.primary == true)
        |> Repo.all()

      assert length(address_names) == 1

      assert %Address.Name{address_hash: ^address_hash, name: "Testit Unitorus", metadata: %{"test" => "toast"}} =
               hd(address_names)
    end
  end
end
