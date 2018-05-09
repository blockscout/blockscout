defmodule Explorer.Indexer.BlockImporterTest do
  # must be `async: false` due to use of named GenServer
  use Explorer.DataCase, async: false

  alias Explorer.Indexer.BlockImporter

  setup do
    start_supervised!({BlockImporter, []})

    :ok
  end

  test "import_blocks" do
    assert :ok =
             BlockImporter.import_blocks(%{
               blocks: [
                 %{
                   difficulty: 340_282_366_920_938_463_463_374_607_431_768_211_454,
                   gas_limit: 6_946_336,
                   gas_used: 50450,
                   hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
                   miner_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                   nonce: 0,
                   number: 37,
                   parent_hash: "0xc37bbad7057945d1bf128c1ff009fb1ad632110bf6a000aac025a80f7766b66e",
                   size: 719,
                   timestamp: Timex.parse!("2017-12-15T21:06:30Z", "{ISO:Extended:Z}"),
                   total_difficulty: 12_590_447_576_074_723_148_144_860_474_975_121_280_509
                 }
               ],
               internal_transactions: [
                 %{
                   call_type: "call",
                   from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                   gas: 4_677_320,
                   gas_used: 27770,
                   index: 0,
                   output: "0x",
                   to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
                   trace_address: [],
                   transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
                   type: "call",
                   value: 0
                 }
               ],
               logs: [
                 %{
                   address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
                   data: "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
                   first_topic: "0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22",
                   fourth_topic: nil,
                   index: 0,
                   second_topic: nil,
                   third_topic: nil,
                   transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
                   type: "mined"
                 }
               ],
               receipts: [
                 %{
                   cumulative_gas_used: 50450,
                   gas_used: 50450,
                   status: :ok,
                   transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
                   transaction_index: 0
                 }
               ],
               transactions: [
                 %{
                   block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
                   from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                   gas: 4_700_000,
                   gas_price: 100_000_000_000,
                   hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
                   index: 0,
                   input: "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
                   nonce: 4,
                   public_key:
                     "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
                   r: "0xa7f8f45cce375bb7af8750416e1b03e0473f93c256da2285d1134fc97a700e01",
                   s: "0x1f87a076f13824f4be8963e3dffd7300dae64d5f23c9a062af0c6ead347c135f",
                   standard_v: "0x1",
                   to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
                   v: "0xbe",
                   value: 0
                 }
               ]
             })
  end
end
