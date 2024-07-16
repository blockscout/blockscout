defmodule Explorer.TokenInstanceOwnerAddressMigration.HelperTest do
  use Explorer.DataCase

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Token.Instance
  alias Explorer.TokenInstanceOwnerAddressMigration.Helper

  {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
  @burn_address_hash burn_address_hash

  describe "fetch_and_insert/2" do
    test "successfully update owner of single token instance" do
      token_address = insert(:contract_address)
      insert(:token, contract_address: token_address, type: "ERC-721")

      instance = insert(:token_instance, token_contract_address_hash: token_address.hash)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      tt_1 =
        insert(:token_transfer,
          token_ids: [instance.token_id],
          transaction: transaction,
          token_contract_address: token_address
        )

      Helper.fetch_and_insert([
        %{token_id: instance.token_id, token_contract_address_hash: instance.token_contract_address_hash}
      ])

      owner_address = tt_1.to_address_hash
      block_number = tt_1.block_number
      log_index = tt_1.log_index

      assert %Instance{
               owner_address_hash: ^owner_address,
               owner_updated_at_block: ^block_number,
               owner_updated_at_log_index: ^log_index
             } =
               Repo.get_by(Instance,
                 token_id: instance.token_id,
                 token_contract_address_hash: instance.token_contract_address_hash
               )
    end

    test "put placeholder value if tt absent in db" do
      instance = insert(:token_instance)

      Helper.fetch_and_insert([
        %{token_id: instance.token_id, token_contract_address_hash: instance.token_contract_address_hash}
      ])

      assert %Instance{
               owner_address_hash: @burn_address_hash,
               owner_updated_at_block: -1,
               owner_updated_at_log_index: -1
             } =
               Repo.get_by(Instance,
                 token_id: instance.token_id,
                 token_contract_address_hash: instance.token_contract_address_hash
               )
    end

    test "update owners of token instances batch" do
      instances =
        for _ <- 0..5 do
          token_address = insert(:contract_address)
          insert(:token, contract_address: token_address, type: "ERC-721")

          instance = insert(:token_instance, token_contract_address_hash: token_address.hash)

          tt =
            for _ <- 0..5 do
              transaction =
                :transaction
                |> insert()
                |> with_block()

              for _ <- 0..5 do
                insert(:token_transfer,
                  token_ids: [instance.token_id],
                  transaction: transaction,
                  token_contract_address: token_address
                )
              end
            end
            |> Enum.concat()
            |> Enum.max_by(fn tt -> {tt.block_number, tt.log_index} end)

          %{
            token_id: instance.token_id,
            token_contract_address_hash: instance.token_contract_address_hash,
            owner_address_hash: tt.to_address_hash,
            owner_updated_at_block: tt.block_number,
            owner_updated_at_log_index: tt.log_index
          }
        end

      Helper.fetch_and_insert(instances)

      for ti <- instances do
        owner_address = ti.owner_address_hash
        block_number = ti.owner_updated_at_block
        log_index = ti.owner_updated_at_log_index

        assert %Instance{
                 owner_address_hash: ^owner_address,
                 owner_updated_at_block: ^block_number,
                 owner_updated_at_log_index: ^log_index
               } =
                 Repo.get_by(Instance,
                   token_id: ti.token_id,
                   token_contract_address_hash: ti.token_contract_address_hash
                 )
      end
    end
  end
end
