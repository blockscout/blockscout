defmodule EthereumJSONRPC.GethTest do
  use EthereumJSONRPC.Case, async: false

  import Mox

  alias EthereumJSONRPC.Geth

  @moduletag :no_parity

  describe "fetch_internal_transactions/2" do
    # Infura Mainnet does not support debug_traceTransaction, so this cannot be tested expect in Mox
    setup do
      EthereumJSONRPC.Case.Geth.Mox.setup()
    end

    setup :verify_on_exit!

    # Data taken from Rinkeby
    test "is supported", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      block_number = 3_287_375
      transaction_index = 13
      transaction_hash = "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5c"
      tracer = File.read!("priv/js/ethereum_jsonrpc/geth/debug_traceTransaction/tracer.js")

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, params: [^transaction_hash, %{tracer: ^tracer}]}], _ ->
        {:ok,
         [
           %{
             id: id,
             result: [
               %{
                 "traceAddress" => [],
                 "type" => "call",
                 "callType" => "call",
                 "from" => "0xa931c862e662134b85e4dc4baf5c70cc9ba74db4",
                 "to" => "0x1469b17ebf82fedf56f04109e5207bdc4554288c",
                 "gas" => "0x8600",
                 "gasUsed" => "0x7d37",
                 "input" => "0xb118e2db0000000000000000000000000000000000000000000000000000000000000008",
                 "output" => "0x",
                 "value" => "0x174876e800"
               }
             ]
           }
         ]}
      end)

      assert {:ok,
              [
                %{
                  block_number: ^block_number,
                  transaction_index: ^transaction_index,
                  transaction_hash: ^transaction_hash,
                  index: 0,
                  trace_address: [],
                  type: "call",
                  call_type: "call",
                  from_address_hash: "0xa931c862e662134b85e4dc4baf5c70cc9ba74db4",
                  to_address_hash: "0x1469b17ebf82fedf56f04109e5207bdc4554288c",
                  gas: 34304,
                  gas_used: 32055,
                  input: "0xb118e2db0000000000000000000000000000000000000000000000000000000000000008",
                  output: "0x",
                  value: 100_000_000_000
                }
              ]} =
               Geth.fetch_internal_transactions(
                 [
                   %{
                     block_number: block_number,
                     transaction_index: transaction_index,
                     hash_data: transaction_hash
                   }
                 ],
                 json_rpc_named_arguments
               )
    end
  end

  describe "fetch_block_internal_transactions/1" do
    test "is not supported", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      EthereumJSONRPC.Geth.fetch_block_internal_transactions([], json_rpc_named_arguments)
    end
  end

  describe "fetch_pending_transactions/1" do
    @tag :no_geth
    test "fetches pending transactions", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn _, _ ->
        {:ok,
         %{
           "pending" => %{
             "0xC99f4e9cFf697ca6717ad9cE8bA4A138e0e55109" => %{
               "4656" => %{
                 "blockHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
                 "blockNumber" => nil,
                 "from" => "0xc99f4e9cff697ca6717ad9ce8ba4a138e0e55109",
                 "gas" => "0x3d0900",
                 "gasPrice" => "0x3b9aca00",
                 "hash" => "0x2b8cfd76a31b942e51b6265c791c860e2840b11f8c2fcfa1c9dfe53dea4c3102",
                 "input" =>
                   "0xc47e300d000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000030af6932dec7c4eaf4b966059e74cc7a1767ba93e62f2d83a7dba5bb785b6efd25e8ab7d2e8798e7ecc27df96380d77a0400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000b29e5229b86fbb3a8e45e406b64226c3d49389804a6f7449325fae232d6623000000000000000000000000000000000000000000000000000000000000006097e4c1ed443f430b1d8ad66e565a960fade76e3e177b4120186bdad2fcfa43e134de3abdc0272c9433af94833fec73260c261cf41422e83d958787b62144478bc44ab84d1ddba7a462d355057f3be8ab914a195ac1a637c4fb8503c441dadb45",
                 "nonce" => "0x1230",
                 "r" => "0x81345ae149171f4cb4ab868f0ad637d033c96c4659b190b86a39725c8299c947",
                 "s" => "0x31450678841d7206fa02b564a641420262cc98c8ea0e32c4cb0e97208d3f9feb",
                 "to" => "0xf003a84d6890202663c0fd80954e836fcf21e004",
                 "transactionIndex" => "0x0",
                 "v" => "0x1b",
                 "value" => "0xb5e620f480000"
               },
               "4657" => %{
                 "blockHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
                 "blockNumber" => nil,
                 "from" => "0xc99f4e9cff697ca6717ad9ce8ba4a138e0e55109",
                 "gas" => "0x3d0900",
                 "gasPrice" => "0x3b9aca00",
                 "hash" => "0x7c3ea924740e996bf552a8dded903ba4258b69d30bf5e6dca6ec86ebc60b8151",
                 "input" =>
                   "0xc47e300d000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000030a25723bca32f88a73abc7eb153cee248effd563d87efe12e08e8a33f74047afc28c30ab9c74bddeb6f0558628b8bf200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020009c56025b2796cdc72f91836278a471590b774462adddd1c87a0b6f84b787990000000000000000000000000000000000000000000000000000000000000060aa53b46c8b57aed7c4c0fdf3f650ec3bb330591929bc813610656882e3203157c22b50d0d0b0316a8712c00fe4f0e0c509613114f5d24c0419a4e8188f2489678b05dccf72a67957785e8e250092c8787f049f7e20b1414a633595a56c98ff82",
                 "nonce" => "0x1231",
                 "r" => "0xee1eb895262d12ef5c4ee3cbf9b36de3903bc3a1343f0a312bd19edacc4bb877",
                 "s" => "0xfcb87efe4c3984a3e1d3f4fb10ce41e59f65e21fbd9206a1648ec73fa0a2206",
                 "to" => "0xf003a84d6890202663c0fd80954e836fcf21e004",
                 "transactionIndex" => "0x0",
                 "v" => "0x1b",
                 "value" => "0xb5e620f480000"
               },
               "4658" => %{
                 "blockHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
                 "blockNumber" => nil,
                 "from" => "0xc99f4e9cff697ca6717ad9ce8ba4a138e0e55109",
                 "gas" => "0x3d0900",
                 "gasPrice" => "0x3b9aca00",
                 "hash" => "0xe699a58ef4986f2dbdc102acf73b35392aff9ce43fd226000526955e19c0b06e",
                 "input" =>
                   "0xc47e300d000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000308eb3ed9e686f6bc1fe2d8ce3fea37fb3a66a9c67b91ef15ba6bd7da0eed73288f72577edea2b7ded5855ca8a56b1e01000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000051afe6c51e2175a62afbd66d293e8a7509943d5cd6f851f59923a61a186e80000000000000000000000000000000000000000000000000000000000000060a063498e8db2e75e0a193de89ad2947111d677c9501e75c34a64fcee8fe5a7c7607929fc6bce943d64f1039e1d1f325f02d1e5d71f86ca976c9ab79d19f0fd0e530a5210fbe131087ba1f1b3c92abc4a0dd7c8a47c3c276fac3e09bca964fd74",
                 "nonce" => "0x1232",
                 "r" => "0xe95bc86fc32cc591677c7ec9ca49f1dc33a31427235c1c41dbb7a3a957b55599",
                 "s" => "0xe8b41a6440d0fe6d0ec1f40982394a2d641b19b983aad49e45614e5f3a1abc9",
                 "to" => "0xf003a84d6890202663c0fd80954e836fcf21e004",
                 "transactionIndex" => "0x0",
                 "v" => "0x1c",
                 "value" => "0xb5e620f480000"
               }
             }
           },
           "queued" => %{}
         }}
      end)

      assert {:ok,
              [
                %{
                  block_hash: nil,
                  block_number: nil,
                  from_address_hash: "0xc99f4e9cff697ca6717ad9ce8ba4a138e0e55109",
                  gas: 4_000_000,
                  gas_price: 1_000_000_000,
                  hash: "0x2b8cfd76a31b942e51b6265c791c860e2840b11f8c2fcfa1c9dfe53dea4c3102",
                  index: nil,
                  input:
                    "0xc47e300d000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000030af6932dec7c4eaf4b966059e74cc7a1767ba93e62f2d83a7dba5bb785b6efd25e8ab7d2e8798e7ecc27df96380d77a0400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000b29e5229b86fbb3a8e45e406b64226c3d49389804a6f7449325fae232d6623000000000000000000000000000000000000000000000000000000000000006097e4c1ed443f430b1d8ad66e565a960fade76e3e177b4120186bdad2fcfa43e134de3abdc0272c9433af94833fec73260c261cf41422e83d958787b62144478bc44ab84d1ddba7a462d355057f3be8ab914a195ac1a637c4fb8503c441dadb45",
                  nonce: 4656,
                  r:
                    58_440_860_745_466_360_584_510_362_592_650_991_653_332_571_230_597_223_185_413_246_840_900_756_818_247,
                  s:
                    22_285_286_687_634_777_993_513_656_263_235_057_426_117_768_584_265_280_722_872_863_042_386_096_267_243,
                  to_address_hash: "0xf003a84d6890202663c0fd80954e836fcf21e004",
                  transaction_index: 0,
                  v: 27,
                  value: 3_200_000_000_000_000
                },
                %{
                  block_hash: nil,
                  block_number: nil,
                  from_address_hash: "0xc99f4e9cff697ca6717ad9ce8ba4a138e0e55109",
                  gas: 4_000_000,
                  gas_price: 1_000_000_000,
                  hash: "0x7c3ea924740e996bf552a8dded903ba4258b69d30bf5e6dca6ec86ebc60b8151",
                  index: nil,
                  input:
                    "0xc47e300d000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000030a25723bca32f88a73abc7eb153cee248effd563d87efe12e08e8a33f74047afc28c30ab9c74bddeb6f0558628b8bf200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020009c56025b2796cdc72f91836278a471590b774462adddd1c87a0b6f84b787990000000000000000000000000000000000000000000000000000000000000060aa53b46c8b57aed7c4c0fdf3f650ec3bb330591929bc813610656882e3203157c22b50d0d0b0316a8712c00fe4f0e0c509613114f5d24c0419a4e8188f2489678b05dccf72a67957785e8e250092c8787f049f7e20b1414a633595a56c98ff82",
                  nonce: 4657,
                  r:
                    107_704_737_317_141_024_268_971_404_113_297_355_261_066_880_504_936_960_891_977_784_149_226_505_877_623,
                  s:
                    7_144_300_886_174_743_587_831_226_472_052_852_957_529_607_874_128_062_849_708_955_356_153_894_281_734,
                  to_address_hash: "0xf003a84d6890202663c0fd80954e836fcf21e004",
                  transaction_index: 0,
                  v: 27,
                  value: 3_200_000_000_000_000
                },
                %{
                  block_hash: nil,
                  block_number: nil,
                  from_address_hash: "0xc99f4e9cff697ca6717ad9ce8ba4a138e0e55109",
                  gas: 4_000_000,
                  gas_price: 1_000_000_000,
                  hash: "0xe699a58ef4986f2dbdc102acf73b35392aff9ce43fd226000526955e19c0b06e",
                  index: nil,
                  input:
                    "0xc47e300d000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000308eb3ed9e686f6bc1fe2d8ce3fea37fb3a66a9c67b91ef15ba6bd7da0eed73288f72577edea2b7ded5855ca8a56b1e01000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000051afe6c51e2175a62afbd66d293e8a7509943d5cd6f851f59923a61a186e80000000000000000000000000000000000000000000000000000000000000060a063498e8db2e75e0a193de89ad2947111d677c9501e75c34a64fcee8fe5a7c7607929fc6bce943d64f1039e1d1f325f02d1e5d71f86ca976c9ab79d19f0fd0e530a5210fbe131087ba1f1b3c92abc4a0dd7c8a47c3c276fac3e09bca964fd74",
                  nonce: 4658,
                  r:
                    105_551_060_165_173_654_536_466_245_809_705_255_348_773_503_447_188_823_324_699_103_004_494_755_354_009,
                  s:
                    6_578_424_718_200_222_268_891_012_570_118_685_130_111_416_504_340_507_122_286_266_818_507_627_932_617,
                  to_address_hash: "0xf003a84d6890202663c0fd80954e836fcf21e004",
                  transaction_index: 0,
                  v: 28,
                  value: 3_200_000_000_000_000
                }
              ]} = Geth.fetch_pending_transactions(json_rpc_named_arguments)
    end
  end
end
