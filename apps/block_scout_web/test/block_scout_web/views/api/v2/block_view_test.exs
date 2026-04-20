defmodule BlockScoutWeb.API.V2.BlockViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.API.V2.BlockView
  alias Explorer.Repo

  describe "burnt_fees_percentage/2" do
    test "returns nil when transaction fees are zero" do
      assert BlockView.burnt_fees_percentage(Decimal.new(50), Decimal.new(0)) == nil
    end

    test "returns nil when transaction fees are nil" do
      assert BlockView.burnt_fees_percentage(Decimal.new(50), nil) == nil
    end

    test "returns nil when burnt fees are nil" do
      assert BlockView.burnt_fees_percentage(nil, Decimal.new(100)) == nil
    end

    test "returns percentage for valid values" do
      assert BlockView.burnt_fees_percentage(Decimal.new(50), Decimal.new(100)) == 50.0
    end
  end

  describe "render/2" do
    test "renders block_countdown.json" do
      result =
        BlockView.render("block_countdown.json", %{
          current_block: 100,
          countdown_block: 200,
          remaining_blocks: 100,
          estimated_time_in_sec: 1200
        })

      assert result.current_block_number == 100
      assert result.countdown_block_number == 200
      assert result.remaining_blocks_count == 100
      assert result.estimated_time_in_seconds == "1200"
    end
  end

  describe "prepare_block/3" do
    test "returns expected block fields" do
      block =
        insert(:block)
        |> Repo.preload([:miner, :uncle_relations, :rewards, :withdrawals, :internal_transactions, :transactions])

      result = BlockView.prepare_block(block, nil)

      assert result["height"] == block.number
      assert result["hash"] == block.hash
      assert result["transactions_count"] == 0
      assert result["uncles_hashes"] == []
      assert result["rewards"] == []
      assert result["withdrawals_count"] == 0
      assert is_map(result["miner"])
    end
  end
end
