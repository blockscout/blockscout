defmodule Phoenix.Param.Explorer.Chain.BlockTest do
  use ExUnit.Case

  import Explorer.Factory

  test "without consensus" do
    block = build(:block, consensus: false)

    assert Phoenix.Param.to_param(block) == to_string(block.hash)
  end

  test "with consensus" do
    block = build(:block, consensus: true)

    assert Phoenix.Param.to_param(block) == to_string(block.number)
  end
end
