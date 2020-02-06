defmodule Explorer.Chain.Cache.UnclesTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Uncles

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, Uncles.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Uncles.child_id())

    :ok
  end

  describe "update_from_second_degree_relations/1" do
    test "fetches an uncle from a second_degree_relation and adds it to the cache" do
      block = insert(:block)
      uncle = insert(:block, consensus: false)

      uncle_hash = uncle.hash

      second_degree_relation = insert(:block_second_degree_relation, uncle_hash: uncle_hash, nephew: block)

      Uncles.update_from_second_degree_relations([second_degree_relation])

      assert [%{hash: uncle_hash}] = Uncles.all()
    end
  end
end
