defmodule BlockScoutWeb.API.V2.OptimismView do
  use BlockScoutWeb, :view

  def render("output_roots.json", %{
        roots: roots,
        total: total,
        next_page_params: next_page_params
      }) do
    %{
      items:
        Enum.map(roots, fn r ->
          %{
            "l2_output_index" => r.l2_output_index,
            "l2_block_number" => r.l2_block_number,
            "l1_tx_hash" => r.l1_tx_hash,
            "l1_timestamp" => r.l1_timestamp,
            "l1_block_number" => r.l1_block_number,
            "output_root" => r.output_root
          }
        end),
      total: total,
      next_page_params: next_page_params
    }
  end
end
