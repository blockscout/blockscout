defmodule BlockScoutWeb.API.V2.TransactionController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @necessity_by_association %{
    :block => :optional,
    :to_address => :optional,
    [created_contract_address: :names] => :optional,
    [from_address: :names] => :optional,
    [to_address: :names] => :optional,
    [to_address: :smart_contract] => :optional
  }

  @token_transfers_neccessity_by_association %{
    [from_address: :smart_contract] => :optional,
    [to_address: :smart_contract] => :optional,
    [from_address: :names] => :optional,
    [to_address: :names] => :optional,
    from_address: :required,
    to_address: :required,
    token: :required
  }

  defp debug(value, key) do
    require Logger
    Logger.configure(truncate: :infinity)
    Logger.info(key)
    Logger.info(Kernel.inspect(value, limit: :infinity, printable_limit: :infinity))
    value
  end

  def transaction(conn, %{"transaction_hash" => transaction_hash_string}) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)},
         {:not_found, {:ok, transaction}} <-
           {:not_found,
            Chain.hash_to_transaction(
              transaction_hash,
              necessity_by_association: @necessity_by_association
            )},
         preloaded <- Chain.preload_token_transfers(transaction, @token_transfers_neccessity_by_association) do
      debug(preloaded, "transaction")

      conn
      |> put_status(200)
      |> render(:transaction, %{transaction: preloaded})
    end
  end

  # %Explorer.Chain.Transaction{created_contract_code_indexed_at: nil, logs: Ecto.Association.NotLoaded<association :logs is not loaded>, r: Decimal<83012678533039828186734074225983425284273347295548639834996965251809177977385>, nonce: 2991, created_contract_address: nil, s: Decimal<2186715792178300161775227672012140953339949319879233853862978515217008478053>, cumulative_gas_used: Decimal<58676>, updated_at: ~U[2022-03-06 14:21:44.845000Z], gas_used: Decimal<58676>, old_block_hash: nil, revert_reason: "4b415032303a207472616e7366657220616d6f756e74206578636565647320616c6c6f77616e6365", created_contract_address_hash: nil, block: %Explorer.Chain.Block{__meta__: Ecto.Schema.Metadata<:loaded, "blocks">, base_fee_per_gas: Explorer.Chain.Wei<7>, consensus: true, difficulty: Decimal<340282366920938463463374607431768211454>, gas_limit: Decimal<12500000>, gas_used: Decimal<58676>, hash: %Explorer.Chain.Hash{byte_count: 32, bytes: <<202, 13, 55, 136, 55, 252, 142, 132, 216, 124, 250, 110, 140, 236, 121, 75, 115, 85, 31, 77, 140, 148, 117, 154, 46, 21, 13, 80, 247, 140, 167, 119>>}, inserted_at: ~U[2022-03-06 14:21:39.856000Z], is_empty: false, miner: Ecto.Association.NotLoaded<association :miner is not loaded>, miner_hash: %Explorer.Chain.Hash{byte_count: 20, bytes: <<78, 32, 34, 99, 85, 180, 70, 76, 248, 243, 182, 127, 195, 24, 183, 83, 167, 193, 37, 179>>}, nephew_relations: Ecto.Association.NotLoaded<association :nephew_relations is not loaded>, nephews: Ecto.Association.NotLoaded<association :nephews is not loaded>, nonce: %Explorer.Chain.Hash{byte_count: 8, bytes: <<0, 0, 0, 0, 0, 0, 0, 0>>}, number: 25522973, parent: Ecto.Association.NotLoaded<association :parent is not loaded>, parent_hash: %Explorer.Chain.Hash{byte_count: 32, bytes: <<152, 18, 115, 219, 178, 6, 166, 229, 88, 38, 235, 48, 174, 38, 41, 207, 152, 248, 67, 73, 28, 1, 138, 98, 118, 101, 141, 243, 27, 211, 198, 172>>}, pending_operations: Ecto.Association.NotLoaded<association :pending_operations is not loaded>, refetch_needed: false, rewards: Ecto.Association.NotLoaded<association :rewards is not loaded>, size: 787, timestamp: ~U[2022-03-06 14:21:30.000000Z], total_difficulty: Decimal<8685017663299205537637196594366619402895071489>, transaction_forks: Ecto.Association.NotLoaded<association :transaction_forks is not loaded>, transactions: Ecto.Association.NotLoaded<association :transactions is not loaded>, uncle_relations: Ecto.Association.NotLoaded<association :uncle_relations is not loaded>, uncles: Ecto.Association.NotLoaded<association :uncles is not loaded>, updated_at: ~U[2022-03-28 09:09:38.028000Z]}, forks: Ecto.Association.NotLoaded<association :forks is not loaded>, gas: Decimal<11875000>, uncles: Ecto.Association.NotLoaded<association :uncles is not loaded>, status: :error, error: "Reverted", gas_price: Explorer.Chain.Wei<2500000007>, to_address_hash: %Explorer.Chain.Hash{byte_count: 20, bytes: <<147, 218, 51, 122, 235, 119, 208, 198, 140, 171, 36, 34, 208, 183, 154, 232, 239, 71, 66, 165>>}, inserted_at: ~U[2022-03-06 14:21:30.841000Z], type: 2, hash: %Explorer.Chain.Hash{byte_count: 32, bytes: <<177, 16, 31, 123, 94, 68, 147, 80, 109, 66, 29, 135, 176, 21, 30, 1, 72, 84, 101, 161, 106, 254, 19, 78, 87, 10, 115, 108, 209, 144, 166, 255>>}, max_priority_fee_per_gas: Explorer.Chain.Wei<2500000000>, input: %Explorer.Chain.Data{bytes: <<35, 184, 114, 221, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 187, 54, 199, 146, 185, 180, 90, 175, 139, 132, 138, 19, 146, 176, 214, 85, 146, 2, 114, 158, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 147, 218, 51, 122, 235, 119, 208, 198, 140, 171, 36, 34, 208, 183, 154, 232, 239, 71, 66, 165, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10>>}, __meta__: Ecto.Schema.Metadata<:loaded, "transactions">, has_error_in_internal_txs: false, earliest_processing_start: nil, internal_transactions: Ecto.Association.NotLoaded<association :internal_transactions is not loaded>, block_number: 25522973, from_address_hash: %Explorer.Chain.Hash{byte_count: 20, bytes: <<187, 54, 199, 146, 185, 180, 90, 175, 139, 132, 138, 19, 146, 176, 214, 85, 146, 2, 114, 158>>}, to_address: %Explorer.Chain.Address{__meta__: Ecto.Schema.Metadata<:loaded, "addresses">, contract_code: , contracts_creation_internal_transaction: Ecto.Association.NotLoaded<association :contracts_creation_internal_transaction is not loaded>, contracts_creation_transaction: Ecto.Association.NotLoaded<association :contracts_creation_transaction is not loaded>, decompiled: false, decompiled_smart_contracts: Ecto.Association.NotLoaded<association :decompiled_smart_contracts is not loaded>, fetched_coin_balance: Explorer.Chain.Wei<0>, fetched_coin_balance_block_number: 25522983, gas_used: 114540, has_decompiled_code?: nil, hash: %Explorer.Chain.Hash{byte_count: 20, bytes: <<147, 218, 51, 122, 235, 119, 208, 198, 140, 171, 36, 34, 208, 183, 154, 232, 239, 71, 66, 165>>}, inserted_at: ~U[2022-02-06 20:28:08.186000Z], names: Ecto.Association.NotLoaded<association :names is not loaded>, nonce: nil, smart_contract: %Explorer.Chain.SmartContract{__meta__: Ecto.Schema.Metadata<:loaded, "smart_contracts">, abi: , "stateMutability" => "nonpayable", "type" => "function"}, %{"inputs" => [], "name" => "unpause", "outputs" => [], "stateMutability" => "nonpayable", "type" => "function"}], address: Ecto.Association.NotLoaded<association :address is not loaded>, address_hash: %Explorer.Chain.Hash{byte_count: 20, bytes: <<147, 218, 51, 122, 235, 119, 208, 198, 140, 171, 36, 34, 208, 183, 154, 232, 239, 71, 66, 165>>}, autodetect_constructor_args: nil, bytecode_checked_at: ~U[2022-04-28 12:30:49.324000Z], compiler_version: "v0.8.11+commit.d7f03943", constructor_arguments: "000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000073d8f731ec0d3945d807a904bf93954b82b0d594000000000000000000000000c5333c0d3cf6fc8f84f3ccb0d5a73dbda2eceb500000000000000000000000002c8abd9c61d4e973ca8db5545c54c90e44a2445c0000000000000000000000000000000000000000000000000000000000000004", contract_code_md5: "4684e9509c65c062dd563c882e5ac5da", contract_source_code: , decompiled_smart_contracts: Ecto.Association.NotLoaded<association :decompiled_smart_contracts is not loaded>, evm_version: "default", external_libraries: [], file_path: nil, id: 38, implementation_name: nil, inserted_at: ~U[2022-02-06 20:52:37.714000Z], is_changed_bytecode: false, is_vyper_contract: false, name: "YESToken", optimization: true, optimization_runs: 200, partially_verified: nil, updated_at: ~U[2022-04-28 12:30:49.505000Z], verified_via_sourcify: nil}, smart_contract_additional_sources: Ecto.Association.NotLoaded<association :smart_contract_additional_sources is not loaded>, stale?: nil, token: Ecto.Association.NotLoaded<association :token is not loaded>, token_transfers_count: 1, transactions_count: 2, updated_at: ~U[2022-04-19 12:08:51.976000Z], verified: true}, token_transfers: [], index: 0, value: Explorer.Chain.Wei<0>, block_hash: %Explorer.Chain.Hash{byte_count: 32, bytes: <<202, 13, 55, 136, 55, 252, 142, 132, 216, 124, 250, 110, 140, 236, 121, 75, 115, 85, 31, 77, 140, 148, 117, 154, 46, 21, 13, 80, 247, 140, 167, 119>>}, v: Decimal<1>, max_fee_per_gas: Explorer.Chain.Wei<2500000014>, from_address: Ecto.Association.NotLoaded<association :from_address is not loaded>}
end
