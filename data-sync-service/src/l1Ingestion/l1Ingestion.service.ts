import { ConfigService } from '@nestjs/config';
import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import {
  L1RelayedMessageEvents,
  L1SentMessageEvents,
  L1ToL2,
  L2RelayedMessageEvents,
  L2SentMessageEvents,
  L2ToL1,
  StateBatches,
  TxnBatches,
} from 'src/typeorm';
import { EntityManager, getConnection, getManager, Repository } from 'typeorm';
import Web3 from 'web3';
import CMGABI from '../abi/L1CrossDomainMessenger.json';
import CTCABI from '../abi/CanonicalTransactionChain.json';
import SCCABI from '../abi/StateCommitmentChain.json';

import { L2IngestionService } from '../l2Ingestion/l2Ingestion.service';

const FraudProofWindow = 0;

@Injectable()
export class L1IngestionService {
  private readonly logger = new Logger(L1IngestionService.name);
  entityManager: EntityManager;
  web3: Web3;
  ctcContract: any;
  sccContract: any;
  crossDomainMessengerContract: any;
  constructor(
    private configService: ConfigService,
    @InjectRepository(L1RelayedMessageEvents)
    private readonly relayedEventsRepository: Repository<L1RelayedMessageEvents>,
    @InjectRepository(L1SentMessageEvents)
    private readonly sentEventsRepository: Repository<L1SentMessageEvents>,
    @InjectRepository(StateBatches)
    private readonly stateBatchesRepository: Repository<StateBatches>,
    @InjectRepository(TxnBatches)
    private readonly txnBatchesRepository: Repository<TxnBatches>,
    @InjectRepository(L2ToL1)
    private readonly txnL2ToL1Repository: Repository<L2ToL1>,
    @InjectRepository(L1ToL2)
    private readonly txnL1ToL2Repository: Repository<L1ToL2>,
    private readonly l2IngestionService: L2IngestionService,
  ) {
    this.entityManager = getManager();
    const web3 = new Web3(
      new Web3.providers.HttpProvider(configService.get('L1_RPC')),
    );
    const crossDomainMessengerContract = new web3.eth.Contract(
      CMGABI as any,
      configService.get('L1_CROSS_DOMAIN_MESSENGER_ADDRESS'),
    );
    const ctcContract = new web3.eth.Contract(
      CTCABI as any,
      configService.get('CTC_ADDRESS'),
    );
    const sccContract = new web3.eth.Contract(
      SCCABI as any,
      configService.get('SCC_ADDRESS'),
    );
    this.ctcContract = ctcContract;
    this.sccContract = sccContract;
    this.crossDomainMessengerContract = crossDomainMessengerContract;
    this.web3 = web3;
  }
  async getCtcTransactionBatchAppendedByBlockNumber(
    fromBlock: number,
    toBlock: number,
  ) {
    return this.ctcContract.getPastEvents('TransactionBatchAppended', {
      fromBlock,
      toBlock,
    });
  }
  async getSccStateBatchAppendedByBlockNumber(
    fromBlock: number,
    toBlock: number,
  ) {
    return this.sccContract.getPastEvents('StateBatchAppended', {
      fromBlock,
      toBlock,
    });
  }
  async getSentMessageByBlockNumber(fromBlock: number, toBlock: number) {
    return this.crossDomainMessengerContract.getPastEvents('SentMessage', {
      fromBlock,
      toBlock,
    });
  }
  async getRelayedMessageByBlockNumber(fromBlock: number, toBlock: number) {
    return this.crossDomainMessengerContract.getPastEvents('RelayedMessage', {
      fromBlock,
      toBlock,
    });
  }
  async getSccTotalElements() {
    return this.sccContract.methods.getTotalElements().call();
  }
  verifyDomainCalldataHash({ target, sender, message, messageNonce }): string {
    const xDomainCalldata = this.web3.eth.abi.encodeFunctionCall(
      {
        name: 'relayMessage',
        type: 'function',
        inputs: [
          { type: 'address', name: 'target' },
          { type: 'address', name: 'sender' },
          { type: 'bytes', name: 'message' },
          { type: 'uint256', name: 'messageNonce' },
        ],
      },
      [target, sender, message, messageNonce],
    );
    return Web3.utils.keccak256(xDomainCalldata);
  }
  async getCurrentBlockNumber(): Promise<number> {
    return this.web3.eth.getBlockNumber();
  }
  async getSentEventsBlockNumber(): Promise<number> {
    const result = await this.sentEventsRepository
      .createQueryBuilder()
      .select('Max(block_number)', 'blockNumber')
      .getRawOne();
    return Number(result.blockNumber) || 0;
  }
  async getRelayedEventsBlockNumber(): Promise<number> {
    const result = await this.relayedEventsRepository
      .createQueryBuilder()
      .select('Max(block_number)', 'blockNumber')
      .getRawOne();
    return Number(result.blockNumber) || 0;
  }
  async getTxnBatchBlockNumber(): Promise<number> {
    const result = await this.txnBatchesRepository
      .createQueryBuilder()
      .select('Max(block_number)', 'blockNumber')
      .getRawOne();
    return Number(result.blockNumber) || 0;
  }
  async getStateBatchBlockNumber(): Promise<number> {
    const result = await this.stateBatchesRepository
      .createQueryBuilder()
      .select('Max(block_number)', 'blockNumber')
      .getRawOne();
    return Number(result.blockNumber) || 0;
  }
  async getUnMergeSentEvents() {
    return this.sentEventsRepository.find({ where: { is_merge: false } });
  }
  async getL2toL1WaitTx(status) {
    return this.txnL2ToL1Repository.find({ where: { status: status } });
  }
  async createTxnBatchesEvents(startBlock, endBlock) {
    const result: any[] = [];
    const list = await this.getCtcTransactionBatchAppendedByBlockNumber(
      startBlock,
      endBlock,
    );
    for (const item of list) {
      const {
        blockNumber,
        transactionHash,
        returnValues: {
          _batchIndex,
          _batchRoot,
          _batchSize,
          _prevTotalElements,
          _signature,
          _extraData,
        },
      } = item;
      const { timestamp } = await this.web3.eth.getBlock(blockNumber);

      const dataSource = getConnection();
      const queryRunner = dataSource.createQueryRunner();
      await queryRunner.connect();
      await queryRunner.startTransaction();
      try {
        const savedResult = await queryRunner.manager.save(TxnBatches, {
          batch_index: _batchIndex,
          block_number: blockNumber.toString(),
          hash: transactionHash,
          size: _batchSize,
          l1_block_number: blockNumber,
          batch_root: _batchRoot,
          extra_data: _extraData,
          pre_total_elements: _prevTotalElements,
          timestamp: new Date(Number(timestamp) * 1000).toISOString(),
          inserted_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        });
        result.push(savedResult);
        await queryRunner.commitTransaction();
      } catch (error) {
        this.logger.error(
          `l1 createTxnBatchesEvents blocknumber:${blockNumber} ${error}`,
        );
        await queryRunner.rollbackTransaction();
      } finally {
        await queryRunner.release();
      }
    }
    return result;
  }
  async createStateBatchesEvents(startBlock, endBlock) {
    const result: any[] = [];
    const list = await this.getSccStateBatchAppendedByBlockNumber(
      startBlock,
      endBlock,
    );
    for (const item of list) {
      const {
        blockNumber,
        transactionHash,
        returnValues: {
          _batchIndex,
          _batchRoot,
          _batchSize,
          _prevTotalElements,
          _extraData,
        },
      } = item;
      const { timestamp } = await this.web3.eth.getBlock(blockNumber);

      const dataSource = getConnection();
      const queryRunner = dataSource.createQueryRunner();
      await queryRunner.connect();
      await queryRunner.startTransaction();
      try {
        const savedResult = await queryRunner.manager.save(StateBatches, {
          batch_index: _batchIndex,
          block_number: blockNumber.toString(),
          hash: transactionHash,
          size: _batchSize,
          l1_block_number: blockNumber,
          batch_root: _batchRoot,
          extra_data: _extraData,
          pre_total_elements: _prevTotalElements,
          timestamp: new Date(Number(timestamp) * 1000).toISOString(),
          inserted_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        });
        result.push(savedResult);
        await queryRunner.commitTransaction();
      } catch (error) {
        this.logger.error(
          `l1 createStateBatchesEvents blocknumber:${blockNumber} ${error}`,
        );
        await queryRunner.rollbackTransaction();
      } finally {
        await queryRunner.release();
      }
    }
    return result;
  }
  async createSentEvents(startBlock, endBlock) {
    const list = await this.getSentMessageByBlockNumber(startBlock, endBlock);
    const result: any[] = [];
    for (const item of list) {
      const {
        blockNumber,
        transactionHash,
        returnValues: { target, sender, message, messageNonce, gasLimit },
        signature,
      } = item;
      const { timestamp } = await this.web3.eth.getBlock(blockNumber);
      const dataSource = getConnection();
      const queryRunner = dataSource.createQueryRunner();
      await queryRunner.connect();
      await queryRunner.startTransaction();
      try {
        const savedResult = await queryRunner.manager.save(
          L1SentMessageEvents,
          {
            tx_hash: transactionHash,
            block_number: blockNumber.toString(),
            target,
            sender,
            message,
            message_nonce: messageNonce,
            gas_limit: gasLimit,
            signature,
            inserted_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          },
        );
        const msgHash = this.verifyDomainCalldataHash({
          target: target.toString(),
          sender: sender.toString(),
          message: message.toString(),
          messageNonce: messageNonce.toString(),
        });
        await queryRunner.manager.save(L1ToL2, {
          hash: transactionHash,
          l2_hash: null,
          msg_hash: msgHash,
          block: blockNumber,
          timestamp: new Date(Number(timestamp) * 1000).toISOString(),
          tx_origin: sender,
          queue_index: Number(messageNonce),
          target: sender,
          gas_limit: gasLimit,
          status: 'Ready for Relay',
          inserted_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        });
        result.push(savedResult);
        await queryRunner.commitTransaction();
      } catch (error) {
        this.logger.error(
          `l1 createSentEvents blocknumber:${blockNumber} ${error}`,
        );
        await queryRunner.rollbackTransaction();
      } finally {
        await queryRunner.release();
      }
    }
    return result;
  }
  async createRelayedEvents(startBlock, endBlock) {
    const list = await this.getRelayedMessageByBlockNumber(
      startBlock,
      endBlock,
    );
    const result: any = [];
    for (const item of list) {
      const {
        blockNumber,
        transactionHash,
        returnValues: { msgHash },
        signature,
      } = item;

      const dataSource = getConnection();
      const queryRunner = dataSource.createQueryRunner();
      await queryRunner.connect();
      await queryRunner.startTransaction();
      try {
        const savedResult = await queryRunner.manager.save(
          L1RelayedMessageEvents,
          {
            tx_hash: transactionHash,
            block_number: blockNumber.toString(),
            msg_hash: msgHash,
            signature,
            inserted_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          },
        );
        result.push(savedResult);
        await queryRunner.commitTransaction();
      } catch (error) {
        this.logger.error(
          `l1 createRelayedEvents blocknumber:${blockNumber} ${error}`,
        );
        await queryRunner.rollbackTransaction();
      } finally {
        await queryRunner.release();
      }
    }
    return result;
  }
  async createL1L2Relation() {
    const unMergeTxList =
      await this.l2IngestionService.getRelayedEventByIsMerge(false);
    for (let i = 0; i < unMergeTxList.length; i++) {
      console.log('unMergeTxList', unMergeTxList[i].msg_hash);
      const l1ToL2Transaction = await this.getL1ToL2TxByMsgHash(
        unMergeTxList[i].msg_hash,
      );
      console.log('l1ToL2Transaction', l1ToL2Transaction.msg_hash);
      const dataSource = getConnection();
      const queryRunner = dataSource.createQueryRunner();
      await queryRunner.connect();
      await queryRunner.startTransaction();
      try {
        // execute some operations on this transaction:
        await queryRunner.manager
          .createQueryBuilder()
          .update(L1ToL2)
          .set({ l2_hash: unMergeTxList[i].tx_hash, status: 'Relayed' })
          .where('hash = :hash', { hash: l1ToL2Transaction.hash })
          .execute();
        await queryRunner.manager
          .createQueryBuilder()
          .update(L1SentMessageEvents)
          .set({ is_merge: true })
          .where('tx_hash = :tx_hash', { tx_hash: l1ToL2Transaction.hash })
          .execute();
        await queryRunner.manager
          .createQueryBuilder()
          .update(L2RelayedMessageEvents)
          .set({ is_merge: true })
          .where('tx_hash = :tx_hash', { tx_hash: unMergeTxList[i].tx_hash })
          .execute();
        // commit transaction now:
        await queryRunner.commitTransaction();
      } catch (err) {
        // since we have errors let's rollback changes we made
        await queryRunner.rollbackTransaction();
      } finally {
        // you need to release query runner which is manually created:
        await queryRunner.release();
      }
    }
  }
  async handleWaitTransaction() {
    const waitTxList = await this.getL2toL1WaitTx('Waiting');
    // const latestBlock = await this.getCurrentBlockNumber();
    // const { timestamp } = await this.web3.eth.getBlock(latestBlock);
    for (let i = 0; i < waitTxList.length; i++) {
      const totalElements = await this.getSccTotalElements();
      const lTimestamp = Number(waitTxList[i].timestamp) / 1000;
      // todo: lTimestamp + FraudProofWindow >= timestamp
      if (totalElements > waitTxList[i].block) {
        const dataSource = getConnection();
        const queryRunner = dataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();
        try {
          await queryRunner.manager
            .createQueryBuilder()
            .update(L2ToL1)
            .set({ status: 'Ready for Relay' })
            .where('l2_hash = :l2_hash', { l2_hash: waitTxList[i].l2_hash })
            .execute();
          await queryRunner.commitTransaction();
        } catch (error) {
          await queryRunner.rollbackTransaction();
        } finally {
          await queryRunner.release();
        }
      }
    }
  }
  async createL2L1Relation() {
    const unMergeTxList = await this.getRelayedEventByIsMerge(false);
    for (let i = 0; i < unMergeTxList.length; i++) {
      const l2ToL1Transaction = await this.getL2ToL1TxByMsgHash(
        unMergeTxList[i].msg_hash,
      );
      const dataSource = getConnection();
      const queryRunner = dataSource.createQueryRunner();
      await queryRunner.connect();
      await queryRunner.startTransaction();
      try {
        await queryRunner.manager
          .createQueryBuilder()
          .update(L2ToL1)
          .set({ hash: unMergeTxList[i].tx_hash, status: 'Relayed' })
          .where('l2_hash = :l2_hash', { l2_hash: l2ToL1Transaction.l2_hash })
          .execute();
        await queryRunner.manager
          .createQueryBuilder()
          .update(L2SentMessageEvents)
          .set({ is_merge: true })
          .where('tx_hash = :tx_hash', { tx_hash: l2ToL1Transaction.l2_hash })
          .execute();
        await queryRunner.manager
          .createQueryBuilder()
          .update(L1RelayedMessageEvents)
          .set({ is_merge: true })
          .where('tx_hash = :tx_hash', { tx_hash: unMergeTxList[i].tx_hash })
          .execute();
        await queryRunner.commitTransaction();
      } catch (error) {
        await queryRunner.rollbackTransaction();
      } finally {
        await queryRunner.release();
      }
    }
  }
  async syncSentEvents() {
    const startBlockNumber = await this.getSentEventsBlockNumber();
    const currentBlockNumber = await this.getCurrentBlockNumber();
    for (let i = startBlockNumber; i < currentBlockNumber; i += 10) {
      const start = i === 0 ? 0 : i + 1;
      const end = Math.min(i + 10, currentBlockNumber);
      const result = await this.createSentEvents(start, end);
      this.logger.log(
        `sync [${result.length}] l1_sent_message_events from block [${start}] to [${end}]`,
      );
    }
  }
  async syncRelayedEvents() {
    const startBlockNumber = await this.getRelayedEventsBlockNumber();
    const currentBlockNumber = await this.getCurrentBlockNumber();
    for (let i = startBlockNumber; i < currentBlockNumber; i += 10) {
      const start = i === 0 ? 0 : i + 1;
      const end = Math.min(i + 10, currentBlockNumber);
      const result = await this.createRelayedEvents(start, end);
      this.logger.log(
        `sync [${result.length}] l1_relayed_message_events from block [${start}] to [${end}]`,
      );
    }
  }
  async sync() {
    this.syncSentEvents();
    this.syncRelayedEvents();
  }
  async getRelayedEventByMsgHash(msgHash: string) {
    return this.relayedEventsRepository.findOne({
      where: { msg_hash: msgHash },
    });
  }
  async getRelayedEventByIsMerge(is_merge: boolean) {
    return this.relayedEventsRepository.find({
      where: { is_merge: is_merge },
    });
  }
  async getL2ToL1TxByMsgHash(msgHash: string) {
    return this.txnL2ToL1Repository.findOne({
      where: { msg_hash: msgHash },
    });
  }
  async getL1ToL2TxByMsgHash(msgHash: string) {
    return this.txnL1ToL2Repository.findOne({
      where: { msg_hash: msgHash },
    });
  }
  async getRelayedEventByTxHash(txHash: string) {
    return this.relayedEventsRepository.findOne({
      where: { tx_hash: txHash },
    });
  }
  async getSentEventByTxHash(txHash: string) {
    return this.sentEventsRepository.findOne({
      where: { tx_hash: txHash },
    });
  }
  async getL1ToL2Relation() {
    const sentList = await this.sentEventsRepository.find();
    const result = [];
    for (const item of sentList) {
      const { target, sender, message, message_nonce } = item;
      const msgHash = this.verifyDomainCalldataHash({
        target: target.toString(),
        sender: sender.toString(),
        message: message.toString(),
        messageNonce: message_nonce.toString(),
      });
      const relayedResult =
        await this.l2IngestionService.getRelayedEventByMsgHash(msgHash);
      result.push({
        block_number: item.block_number,
        queue_index: message_nonce.toString(),
        l2_tx_hash: relayedResult.tx_hash.toString(),
        l1_tx_hash: item.tx_hash.toString(),
        gas_limit: item.gas_limit,
      });
    }
    return result;
  }
  async getL2ToL1Relation() {
    const sentList = await this.l2IngestionService.getAllSentEvents();
    const result = [];
    for (const item of sentList) {
      const { target, sender, message, message_nonce } = item;
      const msgHash = this.l2IngestionService.verifyDomainCalldataHash({
        target: target.toString(),
        sender: sender.toString(),
        message: message.toString(),
        messageNonce: message_nonce.toString(),
      });
      const relayedResult = await this.getRelayedEventByMsgHash(msgHash);
      result.push({
        message_nonce: message_nonce.toString(),
        l2_tx_hash: item.tx_hash.toString(),
        l1_tx_hash: relayedResult ? relayedResult.tx_hash.toString() : null,
      });
    }
    return result;
  }
}
