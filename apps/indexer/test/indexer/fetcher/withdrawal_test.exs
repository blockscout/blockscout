defmodule Indexer.Fetcher.WithdrawalTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox
  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias Indexer.Fetcher.Withdrawal

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    initial_env = Application.get_all_env(:indexer)
    on_exit(fn -> Application.put_all_env([{:indexer, initial_env}]) end)
  end

  test "do not crash app when WITHDRAWALS_FIRST_BLOCK is undefined", %{
    json_rpc_named_arguments: json_rpc_named_arguments
  } do
    Application.put_env(:indexer, Withdrawal.Supervisor, disabled?: "false")
    Withdrawal.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

    assert [{Indexer.Fetcher.Withdrawal, :undefined, :worker, [Indexer.Fetcher.Withdrawal]} | _] =
             Withdrawal.Supervisor |> Supervisor.which_children()
  end

  test "do not start when all old blocks are fetched", %{json_rpc_named_arguments: json_rpc_named_arguments} do
    Application.put_env(:indexer, Withdrawal.Supervisor, disabled?: "false")
    Withdrawal.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

    Application.put_env(:indexer, Withdrawal, first_block: "0")

    assert [{Indexer.Fetcher.Withdrawal, :undefined, :worker, [Indexer.Fetcher.Withdrawal]} | _] =
             Withdrawal.Supervisor |> Supervisor.which_children()
  end

  test "stops when all old blocks are fetched", %{json_rpc_named_arguments: json_rpc_named_arguments} do
    Application.put_env(:indexer, Withdrawal.Supervisor, disabled?: "false")
    Application.put_env(:indexer, Withdrawal, first_block: "0")

    block_a = insert(:block)
    block_b = insert(:block)

    block_a_number_string = integer_to_quantity(block_a.number)
    block_b_number_string = integer_to_quantity(block_b.number)

    EthereumJSONRPC.Mox
    |> expect(:json_rpc, 2, fn requests, _options ->
      {:ok,
       Enum.map(requests, fn
         %{id: id, method: "eth_getBlockByNumber", params: [^block_a_number_string, true]} ->
           %{
             id: id,
             result: %{
               "author" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
               "difficulty" => "0x6bc767dd80781",
               "extraData" => "0x5050594520737061726b706f6f6c2d6574682d7477",
               "gasLimit" => "0x7a121d",
               "gasUsed" => "0x79cbe9",
               "hash" => to_string(block_a.hash),
               "logsBloom" =>
                 "0x044d42d008801488400e1809190200a80d06105bc0c4100b047895c0d518327048496108388040140010b8208006288102e206160e21052322440924002090c1c808a0817405ab238086d028211014058e949401012403210314896702d06880c815c3060a0f0809987c81044488292cc11d57882c912a808ca10471c84460460040000c0001012804022000a42106591881d34407420ba401e1c08a8d00a000a34c11821a80222818a4102152c8a0c044032080c6462644223104d618e0e544072008120104408205c60510542264808488220403000106281a0290404220112c10b080145028c8000300b18a2c8280701c882e702210b00410834840108084",
               "miner" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
               "mixHash" => "0xda53ae7c2b3c529783d6cdacdb90587fd70eb651c0f04253e8ff17de97844010",
               "nonce" => "0x0946e5f01fce12bc",
               "number" => "0x708677",
               "parentHash" => "0x62543e836e0ef7edfa9e38f26526092c4be97efdf5ba9e0f53a4b0b7d5bc930a",
               "receiptsRoot" => "0xa7d2b82bd8526de11736c18bd5cc8cfe2692106c4364526f3310ad56d78669c4",
               "sealFields" => [
                 "0xa0da53ae7c2b3c529783d6cdacdb90587fd70eb651c0f04253e8ff17de97844010",
                 "0x880946e5f01fce12bc"
               ],
               "sha3Uncles" => "0x483a8a21a5825ad270f358b3ea56e060bbb8b3082d9a92ec8fa17a5c7e6fc1b6",
               "size" => "0x544c",
               "stateRoot" => "0x85daa9cd528004c1609d4cb3520fd958e85983bb4183124a4a9f7137fd39c691",
               "timestamp" => "0x5c8bc76e",
               "totalDifficulty" => "0x201a42c35142ae94458",
               "transactions" => [],
               "transactionsRoot" => "0xcd6c12fa43cd4e92ad5c0bf232b30488bbcbfe273c5b4af0366fced0767d54db",
               "uncles" => [],
               "withdrawals" => [
                 %{
                   "index" => "0x1",
                   "validatorIndex" => "0x80b",
                   "address" => "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
                   "amount" => "0x2c17a12dc00"
                 }
               ]
             }
           }

         %{id: id, method: "eth_getBlockByNumber", params: [^block_b_number_string, true]} ->
           %{
             id: id,
             result: %{
               "author" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
               "difficulty" => "0x6bc767dd80781",
               "extraData" => "0x5050594520737061726b706f6f6c2d6574682d7477",
               "gasLimit" => "0x7a121d",
               "gasUsed" => "0x79cbe9",
               "hash" => to_string(block_b.hash),
               "logsBloom" =>
                 "0x044d42d008801488400e1809190200a80d06105bc0c4100b047895c0d518327048496108388040140010b8208006288102e206160e21052322440924002090c1c808a0817405ab238086d028211014058e949401012403210314896702d06880c815c3060a0f0809987c81044488292cc11d57882c912a808ca10471c84460460040000c0001012804022000a42106591881d34407420ba401e1c08a8d00a000a34c11821a80222818a4102152c8a0c044032080c6462644223104d618e0e544072008120104408205c60510542264808488220403000106281a0290404220112c10b080145028c8000300b18a2c8280701c882e702210b00410834840108084",
               "miner" => "0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
               "mixHash" => "0xda53ae7c2b3c529783d6cdacdb90587fd70eb651c0f04253e8ff17de97844010",
               "nonce" => "0x0946e5f01fce12bc",
               "number" => "0x708677",
               "parentHash" => "0x62543e836e0ef7edfa9e38f26526092c4be97efdf5ba9e0f53a4b0b7d5bc930a",
               "receiptsRoot" => "0xa7d2b82bd8526de11736c18bd5cc8cfe2692106c4364526f3310ad56d78669c4",
               "sealFields" => [
                 "0xa0da53ae7c2b3c529783d6cdacdb90587fd70eb651c0f04253e8ff17de97844010",
                 "0x880946e5f01fce12bc"
               ],
               "sha3Uncles" => "0x483a8a21a5825ad270f358b3ea56e060bbb8b3082d9a92ec8fa17a5c7e6fc1b6",
               "size" => "0x544c",
               "stateRoot" => "0x85daa9cd528004c1609d4cb3520fd958e85983bb4183124a4a9f7137fd39c691",
               "timestamp" => "0x5c8bc76e",
               "totalDifficulty" => "0x201a42c35142ae94458",
               "transactions" => [],
               "transactionsRoot" => "0xcd6c12fa43cd4e92ad5c0bf232b30488bbcbfe273c5b4af0366fced0767d54db",
               "uncles" => [],
               "withdrawals" => [
                 %{
                   "index" => "0x2",
                   "validatorIndex" => "0x80b",
                   "address" => "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
                   "amount" => "0x2c17a12dc00"
                 }
               ]
             }
           }
       end)}
    end)

    pid = Withdrawal.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

    assert [{Indexer.Fetcher.Withdrawal, worker_pid, :worker, [Indexer.Fetcher.Withdrawal]} | _] =
             Withdrawal.Supervisor |> Supervisor.which_children()

    assert is_pid(worker_pid)

    :timer.sleep(300)

    assert [{Indexer.Fetcher.Withdrawal, :undefined, :worker, [Indexer.Fetcher.Withdrawal]} | _] =
             Withdrawal.Supervisor |> Supervisor.which_children()

    # Terminates the process so it finishes all Ecto processes.
    GenServer.stop(pid)
  end
end
