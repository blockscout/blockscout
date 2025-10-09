defmodule Explorer.Repo.Migrations.AddNoOverlapIndexToMissingBlockRanges do
  use Ecto.Migration

  def change do
    create(
      constraint(:missing_block_ranges, :missing_block_ranges_no_overlap,
        exclude: ~s|gist (int4range(to_number, from_number, '[]') WITH &&)|
      )
    )
  end
end
