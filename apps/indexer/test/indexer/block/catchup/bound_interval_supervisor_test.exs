defmodule Indexer.Block.Catchup.BoundIntervalSupervisorTest do
  # `async: false` due to use of named GenServer
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Mox
  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias Explorer.Chain.Block
  alias Explorer.Repo
  alias Indexer.BoundInterval
  alias Indexer.Block.Catchup

  alias Indexer.Fetcher.{
    CoinBalance,
    ContractCode,
    InternalTransaction,
    ReplacedTransaction,
    Token,
    TokenBalance,
    UncleBlock
  }

  @moduletag capture_log: true

  # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  setup ctx do
    Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo, :auto)

    on_exit(fn ->
      clear_db()
    end)

    ctx
  end

  describe "start_link/1" do
    # See https://github.com/poanetwork/blockscout/issues/597
    @tag :no_geth
    test "starts fetching blocks from latest and goes down", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      Logger.configure(truncate: :infinity)

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Nethermind ->
            block_number = 3_416_888
            block_quantity = integer_to_quantity(block_number)

            EthereumJSONRPC.Mox
            |> stub(:json_rpc, fn
              # latest block number to seed starting block number for genesis and realtime tasks
              %{method: "eth_getBlockByNumber", params: ["latest", false]}, _options ->
                {:ok,
                 %{
                   "author" => "0xe2ac1c6843a33f81ae4935e5ef1277a392990381",
                   "difficulty" => "0xfffffffffffffffffffffffffffffffe",
                   "extraData" => "0xd583010a068650617269747986312e32362e32826c69",
                   "gasLimit" => "0x7a1200",
                   "gasUsed" => "0x0",
                   "hash" => "0x627baabf5a17c0cfc547b6903ac5e19eaa91f30d9141be1034e3768f6adbc94e",
                   "logsBloom" =>
                     "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                   "miner" => "0xe2ac1c6843a33f81ae4935e5ef1277a392990381",
                   "number" => block_quantity,
                   "parentHash" => "0x006edcaa1e6fde822908783bc4ef1ad3675532d542fce53537557391cfe34c3c",
                   "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                   "sealFields" => [
                     "0x841240b30d",
                     "0xb84158bc4fa5891934bc94c5dca0301867ce4f35925ef46ea187496162668210bba61b4cda09d7e0dca2f1dd041fad498ced6697aeef72656927f52c55b630f2591c01"
                   ],
                   "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                   "signature" =>
                     "58bc4fa5891934bc94c5dca0301867ce4f35925ef46ea187496162668210bba61b4cda09d7e0dca2f1dd041fad498ced6697aeef72656927f52c55b630f2591c01",
                   "size" => "0x243",
                   "stateRoot" => "0x9a8111062667f7b162851a1cbbe8aece5ff12e761b3dcee93b787fcc12548cf7",
                   "step" => "306230029",
                   "timestamp" => "0x5b437f41",
                   "totalDifficulty" => "0x342337ffffffffffffffffffffffffed8d29bb",
                   "transactions" => [],
                   "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                   "uncles" => []
                 }}

              [%{method: "trace_block"} | _] = requests, _options ->
                {:ok, Enum.map(requests, fn %{id: id} -> %{id: id, result: []} end)}

              [%{method: "eth_getBlockByNumber", params: [_, true]} | _] = requests, _options ->
                {:ok,
                 Enum.map(requests, fn %{id: id, params: [block_quantity, true]} ->
                   %{
                     id: id,
                     jsonrpc: "2.0",
                     result: %{
                       "author" => "0xe2ac1c6843a33f81ae4935e5ef1277a392990381",
                       "difficulty" => "0xfffffffffffffffffffffffffffffffe",
                       "extraData" => "0xd583010a068650617269747986312e32362e32826c69",
                       "gasLimit" => "0x7a1200",
                       "gasUsed" => "0x0",
                       "hash" =>
                         Explorer.Factory.block_hash()
                         |> to_string(),
                       "logsBloom" =>
                         "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                       "miner" => "0xe2ac1c6843a33f81ae4935e5ef1277a392990381",
                       "number" => block_quantity,
                       "parentHash" =>
                         Explorer.Factory.block_hash()
                         |> to_string(),
                       "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                       "sealFields" => [
                         "0x841240b30d",
                         "0xb84158bc4fa5891934bc94c5dca0301867ce4f35925ef46ea187496162668210bba61b4cda09d7e0dca2f1dd041fad498ced6697aeef72656927f52c55b630f2591c01"
                       ],
                       "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                       "signature" =>
                         "58bc4fa5891934bc94c5dca0301867ce4f35925ef46ea187496162668210bba61b4cda09d7e0dca2f1dd041fad498ced6697aeef72656927f52c55b630f2591c01",
                       "size" => "0x243",
                       "stateRoot" => "0x9a8111062667f7b162851a1cbbe8aece5ff12e761b3dcee93b787fcc12548cf7",
                       "step" => "306230029",
                       "timestamp" => "0x5b437f41",
                       "totalDifficulty" => "0x342337ffffffffffffffffffffffffed8d29bb",
                       "transactions" => [],
                       "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                       "uncles" => []
                     }
                   }
                 end)}

              [%{method: "eth_getBalance"} | _] = requests, _options ->
                {:ok, Enum.map(requests, fn %{id: id} -> %{id: id, jsonrpc: "2.0", result: "0x0"} end)}

              [], _options ->
                {:ok, []}
            end)

          EthereumJSONRPC.Geth ->
            block_number = 5_950_901
            block_quantity = integer_to_quantity(block_number)

            EthereumJSONRPC.Mox
            |> stub(:json_rpc, fn
              %{method: "eth_getBlockByNumber", params: ["latest", false]}, _options ->
                {:ok,
                 %{
                   "difficulty" => "0xc2550dc5bfc5d",
                   "extraData" => "0x65746865726d696e652d657538",
                   "gasLimit" => "0x7a121d",
                   "gasUsed" => "0x6cc04b",
                   "hash" => "0x71f484056fec687fd469989426c94c469ff08a28eae9a1865359d64557bb99f6",
                   "logsBloom" =>
                     "0x900840000041000850020000002800020800840900200210041006005028810880231200c1a0800001003a00011813005102000020800207080210000020014c00888640001040300c180008000084001000010018010040001118181400a06000280428024010081100015008080814141000644404040a8021101010040001001022000000000880420004008000180004000a01002080890010000a0601001a0000410244421002c0000100920100020004000020c10402004080008000203001000200c4001a000002000c0000000100200410090bc52e080900108230000110010082120200000004e01002000500001009e14001002051000040830080",
                   "miner" => "0xea674fdde714fd979de3edf0f56aa9716b898ec8",
                   "mixHash" => "0x555275cd0ab4c3b2fe3936843ee25bb67da05ef7dcf17216bc0e382d21d139a0",
                   "nonce" => "0xa49e42a024600113",
                   "number" => block_quantity,
                   "parentHash" => "0xb4357733c59cc6f785542d072a205f4e195f7198f544ea5e01c1b90ef0f914a5",
                   "receiptsRoot" => "0x17baf8de366fecc1be494bff245be6357ac60a5fe786099dba89983778c8421e",
                   "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                   "size" => "0x6c7b",
                   "stateRoot" => "0x79345c692a0bf363e95c37750336c534309b3f3fe8b59712ac1527118070f488",
                   "timestamp" => "0x5b475377",
                   "totalDifficulty" => "0x120258e22c69502fc88",
                   "transactions" => ["0xa4b58d1d1473f4891d9ff91f624dba73611bf1f6e9a60d3ca2dcfc75d2ab185c"],
                   "transactionsRoot" => "0x5972b7988f667d7e86679322641117e503ea2c1bc5a27822a8a8120fe53f2c8b",
                   "uncles" => []
                 }}

              [%{method: "eth_getBlockByNumber", params: [_, true]} | _] = requests, _options ->
                {:ok,
                 Enum.map(requests, fn %{id: id, params: [block_quantity, true]} ->
                   %{
                     id: id,
                     jsonrpc: "2.0",
                     result: %{
                       "difficulty" => "0xc22479024e55f",
                       "extraData" => "0x73656f3130",
                       "gasLimit" => "0x7a121d",
                       "gasUsed" => "0x7a0527",
                       "hash" =>
                         Explorer.Factory.block_hash()
                         |> to_string(),
                       "logsBloom" =>
                         "0x006a044c050a6759208088200009808898246808402123144ac15801c09a2672990130000042500000cc6090b063f195352095a88018194112101a02640000a0109c03c40568440b853a800a60044408604bb49d1d604c802008000884520208496608a520992e0f4b41a94188088920c1995107db4696c03839a911500084001009884100605084c4542953b08101103080254c34c802a00042a62f811340400d22080d000c0e39927ca481800c8024048425462000150850500205a224810041904023a80c00dc01040203000086020111210403081096822008c12500a2060a54834800400851210122c481a04a24b5284e9900a08110c180011001c03100",
                       "miner" => "0xb2930b35844a230f00e51431acae96fe543a0347",
                       "mixHash" => "0x5e07a58028d2cee7ddbefe245e6d7b5232d997b66cc906b18ad9ad51535ced24",
                       "nonce" => "0x3d88ebe8031aadf6",
                       "number" => block_quantity,
                       "parentHash" =>
                         Explorer.Factory.block_hash()
                         |> to_string(),
                       "receiptsRoot" => "0x5294a8b56be40c0c198aa443664e801bb926d49878f96151849f3ddd0cb5e76d",
                       "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                       "size" => "0x4796",
                       "stateRoot" => "0x3755d4b5c9ae3cd58d7a856a46fbe8fb69f0ba93d81e831cd68feb8b61bc3009",
                       "timestamp" => "0x5b475393",
                       "totalDifficulty" => "0x120259a450e2527e1e7",
                       "transactions" => [],
                       "transactionsRoot" => "0xa71969ed649cd1f21846ab7b4029e79662941cc34cd473aa4590e666920ad2f4",
                       "uncles" => []
                     }
                   }
                 end)}

              [%{method: "eth_getBalance"} | _] = requests, _options ->
                {:ok, Enum.map(requests, fn %{id: id} -> %{id: id, jsonrpc: "2.0", result: "0x0"} end)}
            end)

          variant_name ->
            raise ArgumentError, "Unsupported variant name (#{variant_name})"
        end
      end

      {:ok, latest_block_number} = EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments)

      default_blocks_batch_size = Catchup.Fetcher.blocks_batch_size()

      assert latest_block_number > default_blocks_batch_size

      assert Repo.aggregate(Block, :count, :hash) == 0

      CoinBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      InternalTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      ContractCode.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      Token.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      TokenBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      ReplacedTransaction.Supervisor.Case.start_supervised!()

      UncleBlock.Supervisor.Case.start_supervised!(
        block_fetcher: %Indexer.Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments}
      )

      Catchup.Supervisor.Case.start_supervised!(%{
        block_fetcher: %Indexer.Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments}
      })

      first_catchup_block_number = latest_block_number - 1

      wait_for_results(fn ->
        Repo.one!(from(block in Block, where: block.number == ^first_catchup_block_number))
      end)

      assert Repo.aggregate(Block, :count, :hash) >= 1

      previous_batch_block_number = first_catchup_block_number - default_blocks_batch_size

      wait_for_results(fn ->
        Repo.one!(from(block in Block, where: block.number == ^previous_batch_block_number))
      end)

      assert Repo.aggregate(Block, :count, :hash) >= default_blocks_batch_size
    end
  end

  describe "Supervisor.count_children/1" do
    setup :supervisor

    test "without task running returns 0 active", %{pid: pid} do
      Supervisor.terminate_child(pid, :task)

      assert Supervisor.count_children(pid) == %{active: 0, specs: 1, supervisors: 0, workers: 1}
    end

    test "with task running returns 1 active", %{pid: pid} do
      assert Supervisor.count_children(pid) == %{active: 1, specs: 1, supervisors: 0, workers: 1}
    end
  end

  describe "Supervisor.delete_child/2" do
    setup :supervisor

    test "with task running returns {:error, :running}", %{pid: pid} do
      assert {:error, :running} = Supervisor.delete_child(pid, :task)
    end

    test "without task running returns {:error, :restarting}", %{pid: pid} do
      Supervisor.terminate_child(pid, :task)

      assert {:error, :restarting} = Supervisor.delete_child(pid, :task)
    end

    test "with unknown child_id returns {:error, :not_found}", %{pid: pid} do
      assert {:error, :not_found} = Supervisor.delete_child(pid, :other)
    end
  end

  describe ":supervisor.get_childspec/2" do
    setup :supervisor

    test "with :task", %{pid: pid} do
      assert {:ok, %{id: :task, modules: [Catchup.Fetcher], restart: _, shutdown: _, start: _, type: :worker}} =
               :supervisor.get_childspec(pid, :task)
    end

    test "with unknown child_id returns {:error, :not_found}", %{pid: pid} do
      assert {:error, :not_found} = :supervisor.get_childspec(pid, :other)
    end
  end

  describe "Supervisor.restart_child/2" do
    setup :supervisor

    test "without :task running restarts task", %{pid: pid} do
      Supervisor.terminate_child(pid, :task)

      assert {:ok, child_pid} = Supervisor.restart_child(pid, :task)

      assert is_pid(child_pid)
    end

    test "with :task running returns {:error, :running}", %{pid: pid} do
      assert {:error, :running} = Supervisor.restart_child(pid, :task)
    end

    test "with unknown child_id returns {:error, :not_found}", %{pid: pid} do
      assert {:error, :not_found} = Supervisor.restart_child(pid, :other)
    end
  end

  describe "Supervisor.start_child/2" do
    setup :supervisor

    test "with map with :task without running returns {:error, :already_present}", %{pid: pid} do
      Supervisor.terminate_child(pid, :task)

      {:ok, child_spec} = :supervisor.get_childspec(pid, :task)

      assert is_map(child_spec)

      assert {:error, :already_present} = Supervisor.start_child(pid, child_spec)
    end

    test "with map with :task with running returns {:error, :already_present, pid}", %{pid: pid} do
      {:ok, child_spec} = :supervisor.get_childspec(pid, :task)

      assert is_map(child_spec)

      assert {:error, :already_present, child_pid} = Supervisor.start_child(pid, child_spec)
      assert is_pid(child_pid)
    end

    test "with tuple with :task without running returns {:error, :already_present}", %{pid: pid} do
      Supervisor.terminate_child(pid, :task)

      {:ok, %{id: id, start: start, restart: restart, shutdown: shutdown, type: type, modules: modules}} =
        :supervisor.get_childspec(pid, :task)

      assert {:error, :already_present} = Supervisor.start_child(pid, {id, start, restart, shutdown, type, modules})
    end

    test "with tuple with :task with running returns {:error, :already_present, pid}", %{pid: pid} do
      {:ok, %{id: id, start: start, restart: restart, shutdown: shutdown, type: type, modules: modules}} =
        :supervisor.get_childspec(pid, :task)

      assert {:error, :already_present, child_pid} =
               Supervisor.start_child(pid, {id, start, restart, shutdown, type, modules})

      assert is_pid(child_pid)
    end

    test "with other child_spec returns {:error, :not_supported}", %{pid: pid} do
      assert {:error, :not_supported} = Supervisor.start_child(pid, %{})
    end
  end

  describe "Supervisor.terminate_child/2" do
    setup :supervisor

    test "with :task without running returns :ok", %{pid: pid} do
      Supervisor.terminate_child(pid, :task)

      assert :ok = Supervisor.terminate_child(pid, :task)
    end

    test "with :task running returns :ok after shutting down child", %{pid: pid} do
      [{:task, child_pid, _, _}] = Supervisor.which_children(pid)

      assert is_pid(child_pid)

      reference = Process.monitor(child_pid)

      assert :ok = Supervisor.terminate_child(pid, :task)

      assert_receive {:DOWN, ^reference, :process, ^child_pid, :shutdown}
    end

    test "with other child_id returns {:error, :not_found}", %{pid: pid} do
      assert {:error, :not_found} = Supervisor.terminate_child(pid, :other)
    end
  end

  describe "Supervisor.which_children/1" do
    setup :supervisor

    test "without task running returns child as :restarting", %{pid: pid} do
      Supervisor.terminate_child(pid, :task)

      assert [{:task, :restarting, :worker, [Catchup.Fetcher]}] = Supervisor.which_children(pid)
    end

    test "with task running returns child as pid", %{pid: pid} do
      assert [{:task, child_pid, :worker, [Catchup.Fetcher]}] = Supervisor.which_children(pid)

      assert is_pid(child_pid)
    end
  end

  describe "handle_info(:catchup_index, state)" do
    setup context do
      # force to use `Mox`, so we can manipulate `latest_block_number`
      put_in(context.json_rpc_named_arguments[:transport], EthereumJSONRPC.Mox)
    end

    setup :state

    test "increases catchup_bound_interval if no blocks missing", %{
      json_rpc_named_arguments: json_rpc_named_arguments,
      state: state
    } do
      insert(:block, number: 0)
      insert(:block, number: 1)

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn %{method: "eth_getBlockByNumber", params: ["latest", false]}, _options ->
        {:ok, %{"number" => "0x1"}}
      end)

      start_supervised!({Task.Supervisor, name: Indexer.Block.Catchup.TaskSupervisor})
      CoinBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      ContractCode.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      InternalTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      Token.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      TokenBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      ReplacedTransaction.Supervisor.Case.start_supervised!()

      # from `setup :state`
      assert_received :catchup_index

      assert {:noreply,
              %Catchup.BoundIntervalSupervisor{fetcher: %Catchup.Fetcher{}, task: %Task{pid: pid, ref: ref}} =
                catchup_index_state} = Catchup.BoundIntervalSupervisor.handle_info(:catchup_index, state)

      assert_receive {^ref, %{first_block_number: 0, missing_block_count: 0}} = message

      Process.sleep(100)

      # DOWN is not flushed
      assert {:messages, [{:DOWN, ^ref, :process, ^pid, :normal}]} = Process.info(self(), :messages)

      assert {:noreply, message_state} = Catchup.BoundIntervalSupervisor.handle_info(message, catchup_index_state)

      # DOWN is flushed
      assert {:messages, []} = Process.info(self(), :messages)

      assert message_state.bound_interval.current > catchup_index_state.bound_interval.current
    end

    test "decreases catchup_bound_interval if blocks missing", %{
      json_rpc_named_arguments: json_rpc_named_arguments,
      state: state
    } do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn %{method: "eth_getBlockByNumber", params: ["latest", false]}, _options ->
        {:ok, %{"number" => "0x1"}}
      end)
      |> expect(:json_rpc, fn [%{id: id, method: "eth_getBlockByNumber", params: ["0x0", true]}], _options ->
        {:ok,
         [
           %{
             id: id,
             jsonrpc: "2.0",
             result: %{
               "difficulty" => "0x0",
               "extraData" => "0x0",
               "gasLimit" => "0x0",
               "gasUsed" => "0x0",
               "hash" =>
                 Explorer.Factory.block_hash()
                 |> to_string(),
               "logsBloom" => "0x0",
               "miner" => "0xb2930b35844a230f00e51431acae96fe543a0347",
               "number" => "0x0",
               "parentHash" =>
                 Explorer.Factory.block_hash()
                 |> to_string(),
               "receiptsRoot" => "0x0",
               "sha3Uncles" => "0x0",
               "size" => "0x0",
               "stateRoot" => "0x0",
               "timestamp" => "0x0",
               "totalDifficulty" => "0x0",
               "transactions" => [],
               "transactionsRoot" => "0x0",
               "uncles" => []
             }
           }
         ]}
      end)
      |> (fn mock ->
            case Keyword.fetch!(json_rpc_named_arguments, :variant) do
              EthereumJSONRPC.Nethermind ->
                expect(mock, :json_rpc, fn [%{method: "trace_block"} | _] = requests, _options ->
                  {:ok, Enum.map(requests, fn %{id: id} -> %{id: id, result: []} end)}
                end)

              _ ->
                mock
            end
          end).()
      |> stub(:json_rpc, fn [
                              %{
                                id: id,
                                method: "eth_getBalance",
                                params: ["0xb2930b35844a230f00e51431acae96fe543a0347", "0x0"]
                              }
                            ],
                            _options ->
        {:ok, [%{id: id, jsonrpc: "2.0", result: "0x0"}]}
      end)

      start_supervised({Task.Supervisor, name: Indexer.Block.Catchup.TaskSupervisor})
      CoinBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      InternalTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      ContractCode.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      Token.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      TokenBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      ReplacedTransaction.Supervisor.Case.start_supervised!()

      UncleBlock.Supervisor.Case.start_supervised!(
        block_fetcher: %Indexer.Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments}
      )

      # from `setup :state`
      assert_received :catchup_index

      assert {:noreply,
              %Catchup.BoundIntervalSupervisor{fetcher: %Catchup.Fetcher{}, task: %Task{pid: pid, ref: ref}} =
                catchup_index_state} = Catchup.BoundIntervalSupervisor.handle_info(:catchup_index, state)

      # 2 blocks are missing, but latest is assumed to be handled by realtime_index, so only 1 is missing for
      # catchup_index
      assert_receive {^ref, %{first_block_number: 0, missing_block_count: 1}} = message, 200

      Process.sleep(200)

      # DOWN is not flushed
      assert {:messages, [{:DOWN, ^ref, :process, ^pid, :normal}]} = Process.info(self(), :messages)

      assert {:noreply, message_state} = Catchup.BoundIntervalSupervisor.handle_info(message, catchup_index_state)

      # DOWN is flushed
      assert {:messages, []} = Process.info(self(), :messages)

      assert message_state.bound_interval.current == message_state.bound_interval.minimum

      # When not at minimum it is decreased

      above_minimum_state = update_in(catchup_index_state.bound_interval, &BoundInterval.increase/1)

      assert above_minimum_state.bound_interval.current > message_state.bound_interval.minimum

      assert {:noreply, above_minimum_message_state} =
               Catchup.BoundIntervalSupervisor.handle_info(message, above_minimum_state)

      assert above_minimum_message_state.bound_interval.current < above_minimum_state.bound_interval.current
    end
  end

  defp state(%{json_rpc_named_arguments: json_rpc_named_arguments}) do
    {:ok, state} =
      Catchup.BoundIntervalSupervisor.init(%{
        block_fetcher: %Indexer.Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments}
      })

    %{state: state}
  end

  defp supervisor(%{json_rpc_named_arguments: json_rpc_named_arguments}) do
    start_supervised!({Task.Supervisor, name: Indexer.Block.Catchup.TaskSupervisor})

    pid =
      start_supervised!(
        {Catchup.BoundIntervalSupervisor,
         [%{block_fetcher: %Indexer.Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments}}]}
      )

    {:ok, %{pid: pid}}
  end
end
