defmodule Explorer.Tags.AddressToTag do
  @moduledoc """
  Represents ann Address to Tag relation.
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Tags.{AddressTag, AddressToTag}

  # Notation.import_types(BlockScoutWeb.Schema.Types)

  @typedoc """
  * `:tag_id` - id of Tag
  * `:address_hash` - hash of Address
  """
  @type t :: %AddressToTag{
          tag_id: Decimal.t(),
          address_hash: Hash.Address.t()
        }

  schema "address_to_tags" do
    belongs_to(
      :tag,
      AddressTag,
      foreign_key: :tag_id,
      references: :id,
      type: :integer
    )

    belongs_to(
      :address,
      Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address
    )

    timestamps()
  end

  @required_attrs ~w(address_hash tag_id)a

  @doc false
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @required_attrs)
    |> unique_constraint([:address_hash, :tag_id], name: :address_to_tags_address_hash_tag_id_index)
  end

  defp get_address_hashes_mapped_to_tag(nil), do: nil

  defp get_address_hashes_mapped_to_tag(tag_id) do
    query =
      from(
        att in AddressToTag,
        where: att.tag_id == ^tag_id,
        select: att.address_hash
      )

    query
    |> Repo.all()
  end

  def set_tag_to_addresses(tag_id, address_hash_string_list) do
    current_address_hashes = get_address_hashes_mapped_to_tag(tag_id)

    current_address_hashes_strings =
      current_address_hashes
      |> Enum.map(fn address_hash ->
        "0x" <> Base.encode16(address_hash.bytes, case: :lower)
      end)

    current_address_hashes_strings_tuples = MapSet.new(current_address_hashes_strings)
    new_address_hashes_strings_tuples = MapSet.new(address_hash_string_list)

    all_tuples = MapSet.union(current_address_hashes_strings_tuples, new_address_hashes_strings_tuples)

    addresses_to_delete =
      all_tuples
      |> MapSet.difference(new_address_hashes_strings_tuples)
      |> MapSet.to_list()

    addresses_to_add =
      all_tuples
      |> MapSet.difference(current_address_hashes_strings_tuples)
      |> MapSet.to_list()

    changeset_to_add_list =
      addresses_to_add
      |> Enum.map(fn address_hash_string ->
        with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
             :ok <- Chain.check_address_exists(address_hash) do
          %{
            tag_id: tag_id,
            address_hash: address_hash,
            inserted_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
          }
        else
          _ ->
            nil
        end
      end)
      |> Enum.filter(&(!is_nil(&1)))

    if Enum.count(addresses_to_delete) > 0 do
      delete_query_base =
        from(
          att in AddressToTag,
          where: att.tag_id == ^tag_id
        )

      delete_query =
        delete_query_base
        |> where_addresses(addresses_to_delete)

      Repo.delete_all(delete_query)
    end

    Repo.insert_all(AddressToTag, changeset_to_add_list,
      on_conflict: :nothing,
      conflict_target: [:address_hash, :tag_id]
    )
  end

  defp where_addresses(query, addresses_to_delete) do
    addresses_to_delete
    |> Enum.reduce(query, fn address_hash_string, acc ->
      case Chain.string_to_address_hash(address_hash_string) do
        {:ok, address_hash} ->
          acc
          |> where(address_hash: ^address_hash)

        _ ->
          acc
      end
    end)
  end
end
