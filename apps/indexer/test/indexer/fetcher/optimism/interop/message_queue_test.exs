defmodule Indexer.Fetcher.Optimism.Interop.MessageQueueTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  alias Indexer.Fetcher.Optimism.Interop.MessageQueue

  describe "set_post_data_signature/3" do
    test "handles signature starting with 0x properly" do
      message_nonce = 1
      init_chain_id = 2
      relay_chain_id = 3
      relay_transaction_hash = "0xf463ce43ac52251f60f437a0346b7168874e6eb13a9689d7efde4ce907826897"
      message_failed = false

      data_to_sign =
        Integer.to_string(message_nonce) <>
          Integer.to_string(init_chain_id) <>
          Integer.to_string(relay_chain_id) <> relay_transaction_hash <> to_string(message_failed)

      private_key =
        <<51, 169, 186, 160, 251, 109, 12, 35, 225, 13, 110, 62, 216, 253, 27, 181, 187, 222, 222, 75, 79, 84, 185, 24,
          245, 213, 28, 21, 76, 179, 162, 16>>

      {:ok, {signature, _}} =
        data_to_sign
        |> ExKeccak.hash_256()
        |> ExSecp256k1.sign_compact(private_key)

      assert {^init_chain_id,
              %{
                signature:
                  "0x3078a19168c4ab6d5aebcb8556d4c6bdf2df53e8b4562f6974ccfaea60639ae13437ee19c4bd7328a5d8451e1c11075d1581e0abf4e470c97d7a89b20e4c68d9"
              }} = MessageQueue.set_post_data_signature(init_chain_id, %{signature: nil}, signature)
    end
  end
end
