defmodule Indexer.Fetcher.Beacon.DepositTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase, async: false

  import ExUnit.CaptureLog, only: [capture_log: 1]
  import Mox
  import Ecto.Query

  alias Explorer.Chain.Beacon.Deposit
  alias Indexer.Fetcher.Beacon.Deposit.Supervisor, as: DepositSupervisor
  alias Indexer.Fetcher.Beacon.Deposit, as: DepositFetcher

  setup :verify_on_exit!
  setup :set_mox_global

  if Application.compile_env(:explorer, :chain_type) == :ethereum do
    setup do
      initial_supervisor_env = Application.get_env(:indexer, DepositSupervisor)
      initial_chain_id = Application.get_env(:indexer, :chain_id)
      initial_fetcher_env = Application.get_env(:indexer, DepositFetcher)

      Application.put_env(:indexer, DepositSupervisor, initial_supervisor_env |> Keyword.put(:disabled?, false))
      Application.put_env(:indexer, :chain_id, "1")
      Application.put_env(:indexer, DepositFetcher, initial_fetcher_env |> Keyword.merge(interval: 1, batch_size: 1))

      on_exit(fn ->
        Application.put_env(:indexer, DepositSupervisor, initial_supervisor_env)
        Application.put_env(:indexer, :chain_id, initial_chain_id)
        Application.put_env(:indexer, DepositFetcher, initial_fetcher_env)
      end)
    end

    @spec_result """
    {
    "data": {
    "CONFIG_NAME": "mainnet",
    "PRESET_BASE": "mainnet",
    "TERMINAL_TOTAL_DIFFICULTY": "58750000000000000000000",
    "TERMINAL_BLOCK_HASH": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "TERMINAL_BLOCK_HASH_ACTIVATION_EPOCH": "18446744073709551615",
    "MIN_GENESIS_ACTIVE_VALIDATOR_COUNT": "16384",
    "MIN_GENESIS_TIME": "1606824000",
    "GENESIS_FORK_VERSION": "0x00000000",
    "GENESIS_DELAY": "604800",
    "ALTAIR_FORK_VERSION": "0x01000000",
    "ALTAIR_FORK_EPOCH": "74240",
    "BELLATRIX_FORK_VERSION": "0x02000000",
    "BELLATRIX_FORK_EPOCH": "144896",
    "CAPELLA_FORK_VERSION": "0x03000000",
    "CAPELLA_FORK_EPOCH": "194048",
    "DENEB_FORK_VERSION": "0x04000000",
    "DENEB_FORK_EPOCH": "269568",
    "ELECTRA_FORK_VERSION": "0x05000000",
    "ELECTRA_FORK_EPOCH": "364032",
    "FULU_FORK_VERSION": "0x06000000",
    "FULU_FORK_EPOCH": "18446744073709551615",
    "SECONDS_PER_SLOT": "12",
    "SECONDS_PER_ETH1_BLOCK": "14",
    "MIN_VALIDATOR_WITHDRAWABILITY_DELAY": "256",
    "SHARD_COMMITTEE_PERIOD": "256",
    "ETH1_FOLLOW_DISTANCE": "2048",
    "SUBNETS_PER_NODE": "2",
    "INACTIVITY_SCORE_BIAS": "4",
    "INACTIVITY_SCORE_RECOVERY_RATE": "16",
    "EJECTION_BALANCE": "16000000000",
    "MIN_PER_EPOCH_CHURN_LIMIT": "4",
    "MAX_PER_EPOCH_ACTIVATION_CHURN_LIMIT": "8",
    "CHURN_LIMIT_QUOTIENT": "65536",
    "PROPOSER_SCORE_BOOST": "40",
    "DEPOSIT_CHAIN_ID": "1",
    "DEPOSIT_NETWORK_ID": "1",
    "DEPOSIT_CONTRACT_ADDRESS": "0x00000000219ab540356cbb839cbe05303d7705fa",
    "GAS_LIMIT_ADJUSTMENT_FACTOR": "1024",
    "MAX_PAYLOAD_SIZE": "10485760",
    "MAX_REQUEST_BLOCKS": "1024",
    "MIN_EPOCHS_FOR_BLOCK_REQUESTS": "33024",
    "TTFB_TIMEOUT": "5",
    "RESP_TIMEOUT": "10",
    "ATTESTATION_PROPAGATION_SLOT_RANGE": "32",
    "MAXIMUM_GOSSIP_CLOCK_DISPARITY_MILLIS": "500",
    "MESSAGE_DOMAIN_INVALID_SNAPPY": "0x00000000",
    "MESSAGE_DOMAIN_VALID_SNAPPY": "0x01000000",
    "ATTESTATION_SUBNET_PREFIX_BITS": "6",
    "MAX_REQUEST_BLOCKS_DENEB": "128",
    "MAX_REQUEST_BLOB_SIDECARS": "768",
    "MAX_REQUEST_DATA_COLUMN_SIDECARS": "16384",
    "MIN_EPOCHS_FOR_BLOB_SIDECARS_REQUESTS": "4096",
    "BLOB_SIDECAR_SUBNET_COUNT": "6",
    "MAX_BLOBS_PER_BLOCK": "6",
    "MIN_PER_EPOCH_CHURN_LIMIT_ELECTRA": "128000000000",
    "MAX_PER_EPOCH_ACTIVATION_EXIT_CHURN_LIMIT": "256000000000",
    "MAX_BLOBS_PER_BLOCK_ELECTRA": "9",
    "BLOB_SIDECAR_SUBNET_COUNT_ELECTRA": "9",
    "MAX_REQUEST_BLOB_SIDECARS_ELECTRA": "1152",
    "NUMBER_OF_COLUMNS": "128",
    "NUMBER_OF_CUSTODY_GROUPS": "128",
    "DATA_COLUMN_SIDECAR_SUBNET_COUNT": "128",
    "SAMPLES_PER_SLOT": "8",
    "CUSTODY_REQUIREMENT": "4",
    "MAX_COMMITTEES_PER_SLOT": "64",
    "TARGET_COMMITTEE_SIZE": "128",
    "MAX_VALIDATORS_PER_COMMITTEE": "2048",
    "SHUFFLE_ROUND_COUNT": "90",
    "HYSTERESIS_QUOTIENT": "4",
    "HYSTERESIS_DOWNWARD_MULTIPLIER": "1",
    "HYSTERESIS_UPWARD_MULTIPLIER": "5",
    "MIN_DEPOSIT_AMOUNT": "1000000000",
    "MAX_EFFECTIVE_BALANCE": "32000000000",
    "EFFECTIVE_BALANCE_INCREMENT": "1000000000",
    "MIN_ATTESTATION_INCLUSION_DELAY": "1",
    "SLOTS_PER_EPOCH": "32",
    "MIN_SEED_LOOKAHEAD": "1",
    "MAX_SEED_LOOKAHEAD": "4",
    "EPOCHS_PER_ETH1_VOTING_PERIOD": "64",
    "SLOTS_PER_HISTORICAL_ROOT": "8192",
    "MIN_EPOCHS_TO_INACTIVITY_PENALTY": "4",
    "EPOCHS_PER_HISTORICAL_VECTOR": "65536",
    "EPOCHS_PER_SLASHINGS_VECTOR": "8192",
    "HISTORICAL_ROOTS_LIMIT": "16777216",
    "VALIDATOR_REGISTRY_LIMIT": "1099511627776",
    "BASE_REWARD_FACTOR": "64",
    "WHISTLEBLOWER_REWARD_QUOTIENT": "512",
    "PROPOSER_REWARD_QUOTIENT": "8",
    "INACTIVITY_PENALTY_QUOTIENT": "67108864",
    "MIN_SLASHING_PENALTY_QUOTIENT": "128",
    "PROPORTIONAL_SLASHING_MULTIPLIER": "1",
    "MAX_PROPOSER_SLASHINGS": "16",
    "MAX_ATTESTER_SLASHINGS": "2",
    "MAX_ATTESTATIONS": "128",
    "MAX_DEPOSITS": "16",
    "MAX_VOLUNTARY_EXITS": "16",
    "INACTIVITY_PENALTY_QUOTIENT_ALTAIR": "50331648",
    "MIN_SLASHING_PENALTY_QUOTIENT_ALTAIR": "64",
    "PROPORTIONAL_SLASHING_MULTIPLIER_ALTAIR": "2",
    "SYNC_COMMITTEE_SIZE": "512",
    "EPOCHS_PER_SYNC_COMMITTEE_PERIOD": "256",
    "MIN_SYNC_COMMITTEE_PARTICIPANTS": "1",
    "INACTIVITY_PENALTY_QUOTIENT_BELLATRIX": "16777216",
    "MIN_SLASHING_PENALTY_QUOTIENT_BELLATRIX": "32",
    "PROPORTIONAL_SLASHING_MULTIPLIER_BELLATRIX": "3",
    "MAX_BYTES_PER_TRANSACTION": "1073741824",
    "MAX_TRANSACTIONS_PER_PAYLOAD": "1048576",
    "BYTES_PER_LOGS_BLOOM": "256",
    "MAX_EXTRA_DATA_BYTES": "32",
    "MAX_BLS_TO_EXECUTION_CHANGES": "16",
    "MAX_WITHDRAWALS_PER_PAYLOAD": "16",
    "MAX_VALIDATORS_PER_WITHDRAWALS_SWEEP": "16384",
    "MAX_BLOB_COMMITMENTS_PER_BLOCK": "4096",
    "FIELD_ELEMENTS_PER_BLOB": "4096",
    "MIN_ACTIVATION_BALANCE": "32000000000",
    "MAX_EFFECTIVE_BALANCE_ELECTRA": "2048000000000",
    "MIN_SLASHING_PENALTY_QUOTIENT_ELECTRA": "4096",
    "WHISTLEBLOWER_REWARD_QUOTIENT_ELECTRA": "4096",
    "PENDING_DEPOSITS_LIMIT": "134217728",
    "PENDING_PARTIAL_WITHDRAWALS_LIMIT": "134217728",
    "PENDING_CONSOLIDATIONS_LIMIT": "262144",
    "MAX_ATTESTER_SLASHINGS_ELECTRA": "1",
    "MAX_ATTESTATIONS_ELECTRA": "8",
    "MAX_DEPOSIT_REQUESTS_PER_PAYLOAD": "8192",
    "MAX_WITHDRAWAL_REQUESTS_PER_PAYLOAD": "16",
    "MAX_CONSOLIDATION_REQUESTS_PER_PAYLOAD": "2",
    "MAX_PENDING_PARTIALS_PER_WITHDRAWALS_SWEEP": "8",
    "MAX_PENDING_DEPOSITS_PER_EPOCH": "16",
    "FIELD_ELEMENTS_PER_CELL": "64",
    "FIELD_ELEMENTS_PER_EXT_BLOB": "8192",
    "KZG_COMMITMENTS_INCLUSION_PROOF_DEPTH": "4",
    "DOMAIN_RANDAO": "0x02000000",
    "DOMAIN_DEPOSIT": "0x03000000",
    "FULL_EXIT_REQUEST_AMOUNT": "0",
    "COMPOUNDING_WITHDRAWAL_PREFIX": "0x02",
    "DOMAIN_SELECTION_PROOF": "0x05000000",
    "SYNC_COMMITTEE_SUBNET_COUNT": "4",
    "UNSET_DEPOSIT_REQUESTS_START_INDEX": "18446744073709551615",
    "DOMAIN_BEACON_PROPOSER": "0x00000000",
    "DOMAIN_VOLUNTARY_EXIT": "0x04000000",
    "VERSIONED_HASH_VERSION_KZG": "1",
    "DOMAIN_BEACON_ATTESTER": "0x01000000",
    "TARGET_AGGREGATORS_PER_SYNC_SUBCOMMITTEE": "16",
    "DOMAIN_APPLICATION_MASK": "0x00000001",
    "DOMAIN_AGGREGATE_AND_PROOF": "0x06000000",
    "ETH1_ADDRESS_WITHDRAWAL_PREFIX": "0x01",
    "TARGET_AGGREGATORS_PER_COMMITTEE": "16",
    "DOMAIN_SYNC_COMMITTEE": "0x07000000",
    "BLS_WITHDRAWAL_PREFIX": "0x00",
    "DOMAIN_SYNC_COMMITTEE_SELECTION_PROOF": "0x08000000",
    "DOMAIN_CONTRIBUTION_AND_PROOF": "0x09000000"
    }
    }
    """

    describe "init/1" do
      test "fetches config and initializes state without deposits in the database", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        Tesla.Test.expect_tesla_call(
          times: 1,
          returns: fn %{url: "http://localhost:5052/eth/v1/config/spec"}, _opts ->
            {:ok, %Tesla.Env{status: 200, body: @spec_result}}
          end
        )

        DepositSupervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

        {_, pid, _, _} =
          Supervisor.which_children(DepositSupervisor) |> Enum.find(fn {name, _, _, _} -> name == DepositFetcher end)

        assert :sys.get_state(pid) == %DepositFetcher{
                 interval: 1,
                 batch_size: 1,
                 deposit_contract_address_hash: "0x00000000219ab540356cbb839cbe05303d7705fa",
                 domain_deposit: <<3, 0, 0, 0>>,
                 genesis_fork_version: <<0, 0, 0, 0>>,
                 deposit_index: -1,
                 last_processed_log_block_number: -1,
                 last_processed_log_index: -1,
                 json_rpc_named_arguments: json_rpc_named_arguments
               }
      end

      test "fetches config and initializes state with deposits in the database", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        Tesla.Test.expect_tesla_call(
          times: 1,
          returns: fn %{url: "http://localhost:5052/eth/v1/config/spec"}, _opts ->
            {:ok, %Tesla.Env{status: 200, body: @spec_result}}
          end
        )

        deposit = insert(:beacon_deposit)

        DepositSupervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

        {_, pid, _, _} =
          Supervisor.which_children(DepositSupervisor) |> Enum.find(fn {name, _, _, _} -> name == DepositFetcher end)

        assert :sys.get_state(pid) == %DepositFetcher{
                 interval: 1,
                 batch_size: 1,
                 deposit_contract_address_hash: "0x00000000219ab540356cbb839cbe05303d7705fa",
                 domain_deposit: <<3, 0, 0, 0>>,
                 genesis_fork_version: <<0, 0, 0, 0>>,
                 deposit_index: deposit.index,
                 last_processed_log_block_number: deposit.block_number,
                 last_processed_log_index: deposit.log_index,
                 json_rpc_named_arguments: json_rpc_named_arguments
               }
      end
    end

    describe "handle_info(:process_logs, state)" do
      @state %DepositFetcher{
        interval: 1,
        batch_size: 1,
        deposit_contract_address_hash: "0x00000000219ab540356cbb839cbe05303d7705fa",
        domain_deposit: <<3, 0, 0, 0>>,
        genesis_fork_version: <<0, 0, 0, 0>>,
        deposit_index: -1,
        last_processed_log_block_number: -1,
        last_processed_log_index: -1
      }

      test "processes logs (batch 1)" do
        deposit_contract_address = insert(:address, hash: "0x00000000219ab540356cbb839cbe05303d7705fa")
        other_contract_address = insert(:address, hash: "0x00000000219ab540356cbb839cbe05303d7705fb")

        insert(:log)
        transaction_a = insert(:transaction) |> with_block()

        log_a =
          insert(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 0,
            transaction: transaction_a,
            block: transaction_a.block
          )

        log_a_transaction_hash = log_a.transaction_hash
        transaction_b = insert(:transaction) |> with_block()

        log_b =
          insert(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 1,
            transaction: transaction_b,
            block: transaction_b.block
          )

        log_b_transaction_hash = log_b.transaction_hash
        # ensure that logs from other contract or with other signature are ignored
        _log_to_be_ignored_b = insert(:beacon_deposit_log, address: other_contract_address, deposit_index: 2)

        {:noreply, new_state} = DepositFetcher.handle_info(:process_logs, @state)
        DepositFetcher.handle_info(:process_logs, new_state)

        assert [
                 %Deposit{transaction_hash: ^log_a_transaction_hash},
                 %Deposit{transaction_hash: ^log_b_transaction_hash}
               ] =
                 Repo.all(from(d in Deposit, order_by: [asc: :index]))
      end

      test "processes logs (batch 5)" do
        state = Map.put(@state, :batch_size, 5)

        deposit_contract_address = insert(:address, hash: "0x00000000219ab540356cbb839cbe05303d7705fa")
        other_contract_address = insert(:address, hash: "0x00000000219ab540356cbb839cbe05303d7705fb")

        insert(:log)
        transaction_a = insert(:transaction) |> with_block()

        log_a =
          insert(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 0,
            transaction: transaction_a,
            block: transaction_a.block
          )

        log_a_transaction_hash = log_a.transaction_hash

        transaction_b = insert(:transaction) |> with_block()

        log_b =
          insert(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 1,
            transaction: transaction_b,
            block: transaction_b.block
          )

        log_b_transaction_hash = log_b.transaction_hash
        # ensure that logs from other contract or with other signature are ignored
        _log_to_be_ignored_b = insert(:beacon_deposit_log, address: other_contract_address, deposit_index: 2)

        DepositFetcher.handle_info(:process_logs, state)

        assert [
                 %Deposit{transaction_hash: ^log_a_transaction_hash},
                 %Deposit{transaction_hash: ^log_b_transaction_hash}
               ] =
                 Repo.all(from(d in Deposit, order_by: [asc: :index]))
      end

      test "fallbacks to fetch data from the node when non-sequential logs are detected (logs starts not from 0, between batches)",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        deposit_contract_address = insert(:address, hash: "0x00000000219ab540356cbb839cbe05303d7705fa")

        log_from_node =
          build(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 0
          )

        deposit_signature = log_from_node.first_topic
        log_from_node_block_number_quantity = EthereumJSONRPC.integer_to_quantity(log_from_node.block_number)
        log_from_node_transaction_hash = log_from_node.transaction.hash

        transaction_a = insert(:transaction) |> with_block()

        log_a =
          insert(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 1,
            transaction: transaction_a,
            block: transaction_a.block
          )

        log_a_transaction_hash = log_a.transaction_hash
        log_a_block_number_quantity = EthereumJSONRPC.integer_to_quantity(log_a.block_number)

        transaction_b = insert(:transaction) |> with_block()

        log_b =
          insert(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 2,
            transaction: transaction_b,
            block: transaction_b.block
          )

        log_b_transaction_hash = log_b.transaction_hash

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, 2, fn
          %{
            id: _id,
            method: "eth_getLogs",
            params: [
              %{
                address: "0x00000000219ab540356cbb839cbe05303d7705fa",
                topics: [^deposit_signature],
                fromBlock: "0x0",
                toBlock: ^log_a_block_number_quantity
              }
            ]
          },
          _options ->
            {:ok,
             [
               %{
                 "address" => "0x7f02c3e3c98b133055b8b348b2ac625669ed295d",
                 "blockHash" => to_string(log_from_node.block.hash),
                 "blockNumber" => log_from_node_block_number_quantity,
                 "data" => to_string(log_from_node.data),
                 "logIndex" => "0x1",
                 "removed" => false,
                 "topics" => [
                   "0x649bbc62d0e31342afea4e5cd82d4049e7e1ee912fc0889aa790803be39038c5"
                 ],
                 "transactionHash" => to_string(log_from_node_transaction_hash),
                 "transactionIndex" => "0x4"
               }
             ]}

          [
            %{
              id: id,
              method: "eth_getBlockByNumber",
              params: [^log_from_node_block_number_quantity, false]
            }
          ],
          _options ->
            {:ok,
             [
               %{
                 id: id,
                 result: %{
                   "difficulty" => "0xa3ff9e",
                   "extraData" => "0x",
                   "gasLimit" => "0x1c9c380",
                   "gasUsed" => "0x0",
                   "hash" => to_string(log_from_node.block.hash),
                   "logsBloom" =>
                     "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                   "miner" => "0x2f14582947e292a2ecd20c430b46f2d27cfe213c",
                   "mixHash" => "0xa85d26c4efa1d9fdbb095935b49c93a1ddcc967634d899826168abe486f095d8",
                   "nonce" => "0xc7faaf72b6690188",
                   "number" => log_from_node_block_number_quantity,
                   "parentHash" => "0x8ac578a998c3af00a0eab91f7fa209aeed0251c61c37f3b1d43d4253a5e2fa7a",
                   "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                   "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                   "size" => "0x203",
                   "stateRoot" => "0xd432683a9704dcabff1daacf8c40742301248faf3d9f05ea738daa2dffc19043",
                   "totalDifficulty" => "0x5113296ac",
                   "timestamp" => "0x617383e7",
                   "baseFeePerGas" => "0x7",
                   "transactions" => [],
                   "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                   "uncles" => []
                 }
               }
             ]}
        end)

        log =
          capture_log(fn ->
            DepositFetcher.handle_info(
              :process_logs,
              Map.put(@state, :json_rpc_named_arguments, json_rpc_named_arguments)
            )
            |> then(fn {:noreply, new_state} ->
              DepositFetcher.handle_info(
                :process_logs,
                new_state
              )
            end)
            |> then(fn {:noreply, new_state} ->
              DepositFetcher.handle_info(
                :process_logs,
                new_state
              )
            end)
          end)

        assert log =~ "Non-sequential deposits detected"

        assert [
                 %Deposit{transaction_hash: ^log_from_node_transaction_hash, index: 0},
                 %Deposit{transaction_hash: ^log_a_transaction_hash, index: 1},
                 %Deposit{transaction_hash: ^log_b_transaction_hash, index: 2}
               ] =
                 Repo.all(from(d in Deposit, order_by: [asc: :index]))
      end

      test "fallbacks to fetch data from the node when non-sequential logs are detected (non-sequential between, between batches)",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        deposit_contract_address = insert(:address, hash: "0x00000000219ab540356cbb839cbe05303d7705fa")

        transaction_a = insert(:transaction) |> with_block()

        log_a =
          insert(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 0,
            transaction: transaction_a,
            block: transaction_a.block
          )

        log_a_transaction_hash = log_a.transaction_hash
        log_a_block_number_quantity = EthereumJSONRPC.integer_to_quantity(log_a.block_number)

        transaction_with_missing_logs = insert(:transaction) |> with_block()

        log_from_node =
          build(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 1,
            transaction: transaction_with_missing_logs,
            block: transaction_with_missing_logs.block
          )

        deposit_signature = log_from_node.first_topic
        log_from_node_block_number_quantity = EthereumJSONRPC.integer_to_quantity(log_from_node.block_number)
        log_from_node_transaction_hash = log_from_node.transaction.hash

        transaction_b = insert(:transaction) |> with_block()

        log_b =
          insert(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 2,
            transaction: transaction_b,
            block: transaction_b.block
          )

        log_b_transaction_hash = log_b.transaction_hash
        log_b_block_number_quantity = EthereumJSONRPC.integer_to_quantity(log_b.block_number)

        transaction_c = insert(:transaction) |> with_block()

        _log_c =
          insert(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 3,
            transaction: transaction_c,
            block: transaction_c.block
          )

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, 1, fn
          %{
            id: _id,
            method: "eth_getLogs",
            params: [
              %{
                address: "0x00000000219ab540356cbb839cbe05303d7705fa",
                topics: [^deposit_signature],
                fromBlock: ^log_a_block_number_quantity,
                toBlock: ^log_b_block_number_quantity
              }
            ]
          },
          _options ->
            {:ok,
             [
               %{
                 "address" => "0x7f02c3e3c98b133055b8b348b2ac625669ed295d",
                 "blockHash" => to_string(log_from_node.block.hash),
                 "blockNumber" => log_from_node_block_number_quantity,
                 "data" => to_string(log_from_node.data),
                 "logIndex" => "0x1",
                 "removed" => false,
                 "topics" => [
                   "0x649bbc62d0e31342afea4e5cd82d4049e7e1ee912fc0889aa790803be39038c5"
                 ],
                 "transactionHash" => to_string(log_from_node_transaction_hash),
                 "transactionIndex" => "0x4"
               }
             ]}
        end)

        {:noreply, new_state} =
          DepositFetcher.handle_info(
            :process_logs,
            Map.put(@state, :json_rpc_named_arguments, json_rpc_named_arguments)
          )

        log = capture_log(fn -> DepositFetcher.handle_info(:process_logs, new_state) end)

        assert log =~ "Non-sequential deposits detected"

        assert [
                 %Deposit{transaction_hash: ^log_a_transaction_hash},
                 %Deposit{transaction_hash: ^log_from_node_transaction_hash},
                 %Deposit{transaction_hash: ^log_b_transaction_hash}
               ] = Repo.all(from(d in Deposit, order_by: [asc: :index]))
      end

      test "fallbacks to fetch data from the node when non-sequential logs are detected (logs starts not from 0, inside batch)",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        state = @state |> Map.put(:batch_size, 5) |> Map.put(:json_rpc_named_arguments, json_rpc_named_arguments)

        deposit_contract_address = insert(:address, hash: "0x00000000219ab540356cbb839cbe05303d7705fa")

        log_from_node =
          build(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 0
          )

        deposit_signature = log_from_node.first_topic
        log_from_node_block_number_quantity = EthereumJSONRPC.integer_to_quantity(log_from_node.block_number)
        log_from_node_transaction_hash = log_from_node.transaction.hash

        transaction_a = insert(:transaction) |> with_block()

        log_a =
          insert(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 1,
            transaction: transaction_a,
            block: transaction_a.block
          )

        log_a_transaction_hash = log_a.transaction_hash
        log_a_block_number_quantity = EthereumJSONRPC.integer_to_quantity(log_a.block_number)

        transaction_b = insert(:transaction) |> with_block()

        log_b =
          insert(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 2,
            transaction: transaction_b,
            block: transaction_b.block
          )

        log_b_transaction_hash = log_b.transaction_hash

        transaction_c = insert(:transaction) |> with_block()

        log_c =
          insert(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 3,
            transaction: transaction_c,
            block: transaction_c.block
          )

        log_c_transaction_hash = log_c.transaction_hash

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, 2, fn
          %{
            id: _id,
            method: "eth_getLogs",
            params: [
              %{
                address: "0x00000000219ab540356cbb839cbe05303d7705fa",
                topics: [^deposit_signature],
                fromBlock: "0x0",
                toBlock: ^log_a_block_number_quantity
              }
            ]
          },
          _options ->
            {:ok,
             [
               %{
                 "address" => "0x7f02c3e3c98b133055b8b348b2ac625669ed295d",
                 "blockHash" => to_string(log_from_node.block.hash),
                 "blockNumber" => log_from_node_block_number_quantity,
                 "data" => to_string(log_from_node.data),
                 "logIndex" => "0x1",
                 "removed" => false,
                 "topics" => [
                   "0x649bbc62d0e31342afea4e5cd82d4049e7e1ee912fc0889aa790803be39038c5"
                 ],
                 "transactionHash" => to_string(log_from_node_transaction_hash),
                 "transactionIndex" => "0x4"
               }
             ]}

          [
            %{
              id: id,
              method: "eth_getBlockByNumber",
              params: [^log_from_node_block_number_quantity, false]
            }
          ],
          _options ->
            {:ok,
             [
               %{
                 id: id,
                 result: %{
                   "difficulty" => "0xa3ff9e",
                   "extraData" => "0x",
                   "gasLimit" => "0x1c9c380",
                   "gasUsed" => "0x0",
                   "hash" => to_string(log_from_node.block.hash),
                   "logsBloom" =>
                     "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                   "miner" => "0x2f14582947e292a2ecd20c430b46f2d27cfe213c",
                   "mixHash" => "0xa85d26c4efa1d9fdbb095935b49c93a1ddcc967634d899826168abe486f095d8",
                   "nonce" => "0xc7faaf72b6690188",
                   "number" => log_from_node_block_number_quantity,
                   "parentHash" => "0x8ac578a998c3af00a0eab91f7fa209aeed0251c61c37f3b1d43d4253a5e2fa7a",
                   "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                   "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                   "size" => "0x203",
                   "stateRoot" => "0xd432683a9704dcabff1daacf8c40742301248faf3d9f05ea738daa2dffc19043",
                   "totalDifficulty" => "0x5113296ac",
                   "timestamp" => "0x617383e7",
                   "baseFeePerGas" => "0x7",
                   "transactions" => [],
                   "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                   "uncles" => []
                 }
               }
             ]}
        end)

        log = capture_log(fn -> DepositFetcher.handle_info(:process_logs, state) end)

        assert log =~ "Non-sequential deposits detected"

        assert [
                 %Deposit{transaction_hash: ^log_from_node_transaction_hash},
                 %Deposit{transaction_hash: ^log_a_transaction_hash},
                 %Deposit{transaction_hash: ^log_b_transaction_hash},
                 %Deposit{transaction_hash: ^log_c_transaction_hash}
               ] = Repo.all(from(d in Deposit, order_by: [asc: :index]))
      end

      test "fallbacks to fetch data from the node when non-sequential logs are detected (non-sequential between, inside batch)",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        state = @state |> Map.put(:batch_size, 5) |> Map.put(:json_rpc_named_arguments, json_rpc_named_arguments)

        deposit_contract_address = insert(:address, hash: "0x00000000219ab540356cbb839cbe05303d7705fa")

        transaction_a = insert(:transaction) |> with_block()

        log_a =
          insert(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 0,
            transaction: transaction_a,
            block: transaction_a.block
          )

        log_a_transaction_hash = log_a.transaction_hash
        log_a_block_number_quantity = EthereumJSONRPC.integer_to_quantity(log_a.block_number)

        log_from_node =
          build(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 1
          )

        deposit_signature = log_from_node.first_topic
        log_from_node_block_number_quantity = EthereumJSONRPC.integer_to_quantity(log_from_node.block_number)
        log_from_node_transaction_hash = log_from_node.transaction.hash

        transaction_b = insert(:transaction) |> with_block()

        log_b =
          insert(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 2,
            transaction: transaction_b,
            block: transaction_b.block
          )

        log_b_transaction_hash = log_b.transaction_hash
        log_b_block_number_quantity = EthereumJSONRPC.integer_to_quantity(log_b.block_number)

        transaction_c = insert(:transaction) |> with_block()

        log_c =
          insert(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 3,
            transaction: transaction_c,
            block: transaction_c.block
          )

        log_c_transaction_hash = log_c.transaction_hash

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, 2, fn
          %{
            id: _id,
            method: "eth_getLogs",
            params: [
              %{
                address: "0x00000000219ab540356cbb839cbe05303d7705fa",
                topics: [^deposit_signature],
                fromBlock: ^log_a_block_number_quantity,
                toBlock: ^log_b_block_number_quantity
              }
            ]
          },
          _options ->
            {:ok,
             [
               %{
                 "address" => "0x7f02c3e3c98b133055b8b348b2ac625669ed295d",
                 "blockHash" => to_string(log_from_node.block.hash),
                 "blockNumber" => log_from_node_block_number_quantity,
                 "data" => to_string(log_from_node.data),
                 "logIndex" => "0x1",
                 "removed" => false,
                 "topics" => [
                   "0x649bbc62d0e31342afea4e5cd82d4049e7e1ee912fc0889aa790803be39038c5"
                 ],
                 "transactionHash" => to_string(log_from_node_transaction_hash),
                 "transactionIndex" => "0x4"
               }
             ]}

          [
            %{
              id: id,
              method: "eth_getBlockByNumber",
              params: [^log_from_node_block_number_quantity, false]
            }
          ],
          _options ->
            {:ok,
             [
               %{
                 id: id,
                 result: %{
                   "difficulty" => "0xa3ff9e",
                   "extraData" => "0x",
                   "gasLimit" => "0x1c9c380",
                   "gasUsed" => "0x0",
                   "hash" => to_string(log_from_node.block.hash),
                   "logsBloom" =>
                     "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                   "miner" => "0x2f14582947e292a2ecd20c430b46f2d27cfe213c",
                   "mixHash" => "0xa85d26c4efa1d9fdbb095935b49c93a1ddcc967634d899826168abe486f095d8",
                   "nonce" => "0xc7faaf72b6690188",
                   "number" => log_from_node_block_number_quantity,
                   "parentHash" => "0x8ac578a998c3af00a0eab91f7fa209aeed0251c61c37f3b1d43d4253a5e2fa7a",
                   "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                   "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                   "size" => "0x203",
                   "stateRoot" => "0xd432683a9704dcabff1daacf8c40742301248faf3d9f05ea738daa2dffc19043",
                   "totalDifficulty" => "0x5113296ac",
                   "timestamp" => "0x617383e7",
                   "baseFeePerGas" => "0x7",
                   "transactions" => [],
                   "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
                   "uncles" => []
                 }
               }
             ]}
        end)

        log = capture_log(fn -> DepositFetcher.handle_info(:process_logs, state) end)

        assert log =~ "Non-sequential deposits detected"

        assert [
                 %Deposit{transaction_hash: ^log_a_transaction_hash},
                 %Deposit{transaction_hash: ^log_from_node_transaction_hash},
                 %Deposit{transaction_hash: ^log_b_transaction_hash},
                 %Deposit{transaction_hash: ^log_c_transaction_hash}
               ] = Repo.all(from(d in Deposit, order_by: [asc: :index]))
      end

      test "signature verification" do
        state = Map.put(@state, :batch_size, 5)

        deposit_contract_address = insert(:address, hash: "0x00000000219ab540356cbb839cbe05303d7705fa")

        transaction_a = insert(:transaction) |> with_block()

        _valid_log =
          insert(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_pubkey:
              Base.decode16!(
                "b325d901d41957b6746088a61f5a1562f09ccb184e1628fa63b6bdfe9a724645d536484e4d26e8c9b653aaf0501cefe1",
                case: :mixed
              ),
            deposit_withdrawal_credentials:
              Base.decode16!("0100000000000000000000001ed8b3e4278184675fefa6981dea36f4535df417", case: :mixed),
            deposit_amount: 32_000_000_000,
            deposit_signature:
              Base.decode16!(
                "a519a7ff525a6831a6099399033bb5a0b959ec7af022ad7f37aa869927bbb59e1271079cbdff416e7f8f6f0f8ea7173304f4abdabfa65923a6b0304d49c97cef0690d0017b39518e7b19848657e2a9f73601d5037c217c5252558be1a8176e3d",
                case: :mixed
              ),
            deposit_index: 0,
            transaction: transaction_a,
            block: transaction_a.block
          )

        transaction_b = insert(:transaction) |> with_block()

        _invalid_log =
          insert(:beacon_deposit_log,
            address: deposit_contract_address,
            deposit_index: 1,
            transaction: transaction_b,
            block: transaction_b.block
          )

        DepositFetcher.handle_info(:process_logs, state)

        assert [%Deposit{status: :pending, index: 0}, %Deposit{status: :invalid, index: 1}] =
                 Repo.all(from(d in Deposit, order_by: [asc: :index]))
      end
    end
  end
end
