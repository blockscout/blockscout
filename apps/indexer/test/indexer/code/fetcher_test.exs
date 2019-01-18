defmodule Indexer.Code.FetcherTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import EthereumJSONRPC, only: [integer_to_quantity: 1, quantity_to_integer: 1]

  import Mox

  alias Explorer.Chain.{Address, Transaction}
  alias Indexer.Code

  @moduletag :capture_log

  # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

    :ok
  end

  describe "async_fetch/1" do
    test "fetched codes for address_hashes", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      variant = Keyword.fetch!(json_rpc_named_arguments, :variant)

      %{block_number: block_number, code: code, address: address, hash: hash} =
        case variant do
          EthereumJSONRPC.Geth ->
            %{
              block_number: 201_480,
              code: "0x3838533838f3",
              address: %Explorer.Chain.Hash{
                byte_count: 20,
                bytes:
                  <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132, 89, 192, 16, 79, 223, 94, 152, 122, 202>>
              },
              hash: %Explorer.Chain.Hash{
                byte_count: 32,
                bytes:
                  <<0x9FC76417374AA880D4449A1F7F31EC597F00B1F6F3DD2D66F4C9C6C445836D8B::big-integer-size(32)-unit(8)>>
              }
            }

          EthereumJSONRPC.Parity ->
            %{
              block_number: 34,
              code: "0x3838533838f3",
              address: %Explorer.Chain.Hash{
                byte_count: 20,
                bytes:
                  <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132, 89, 192, 16, 79, 223, 94, 152, 122, 202>>
              },
              hash: %Explorer.Chain.Hash{
                byte_count: 32,
                bytes:
                  <<0x9FC76417374AA880D4449A1F7F31EC597F00B1F6F3DD2D66F4C9C6C445836D8B::big-integer-size(32)-unit(8)>>
              }
            }

          variant ->
            raise ArgumentError, "Unsupported variant (#{variant})"
        end

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        block_quantity = integer_to_quantity(block_number)
        address = to_string(address)

        {block_quantity, address} |> IO.inspect()

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [%{id: id, method: "eth_getCode", params: [^address, ^block_quantity]}], _options ->
          {:ok, [%{id: id, result: code}]}
        end)
      end

      insert(:address, hash: address)
      insert(:transaction, hash: hash, created_contract_address_hash: address)

      Code.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      assert :ok =
               Code.Fetcher.async_fetch([
                 %{created_contract_address_hash: address, block_number: block_number, hash: hash}
               ])

      fetched_address =
        wait(fn ->
          Repo.one!(from(address in Address, where: address.hash == ^address and not is_nil(address.contract_code)))
        end)

      assert to_string(fetched_address.contract_code) == code

      updated_transaction = Repo.one!(from(transaction in Transaction, where: transaction.hash == ^hash))

      assert updated_transaction.created_contract_code_indexed_at
    end
  end

  defp wait(producer) do
    producer.()
  rescue
    Ecto.NoResultsError ->
      Process.sleep(100)
      wait(producer)
  end
end
