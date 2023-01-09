import { Injectable, Logger, Inject, CACHE_MANAGER } from '@nestjs/common';
import { Cache } from 'cache-manager';
import { Interval } from '@nestjs/schedule';
import { L1IngestionService } from '../l1Ingestion/l1Ingestion.service';
import { L2IngestionService } from '../l2Ingestion/l2Ingestion.service';
import { ConfigService } from '@nestjs/config';

const L1_SENT = 'l1_sent_block_number';
const L1_RELAYED = 'l1_relayed_block_number';
const L2_SENT = 'l2_sent_block_number';
const L2_RELAYED = 'l2_relayed_block_number';
const TXN_BATCH = 'txn_batch_block_number';
const STATE_BATCH = 'state_batch_block_number';
const SYNC_STEP = 10;

@Injectable()
export class TasksService {
  constructor(
    private configService: ConfigService,
    private readonly l1IngestionService: L1IngestionService,
    private readonly l2IngestionService: L2IngestionService,
    @Inject(CACHE_MANAGER) private cacheManager: Cache,
  ) {
    this.initCache();
  }
  private readonly logger = new Logger(TasksService.name);
  async initCache() {
    let l1_sent_block_number = await this.cacheManager.get(L1_SENT);
    let l1_relayed_block_number = await this.cacheManager.get(L1_RELAYED);
    let l2_sent_block_number = await this.cacheManager.get(L2_SENT);
    let l2_relayed_block_number = await this.cacheManager.get(L2_RELAYED);
    let txn_batch_block_number = await this.cacheManager.get(TXN_BATCH);
    let state_batch_block_number = await this.cacheManager.get(STATE_BATCH);
    if (!l1_sent_block_number) {
      l1_sent_block_number =
        (await this.l1IngestionService.getSentEventsBlockNumber()) ||
        this.configService.get('L1_START_BLOCK_NUMBER');
    }
    if (!l1_relayed_block_number) {
      l1_relayed_block_number =
        (await this.l1IngestionService.getRelayedEventsBlockNumber()) ||
        this.configService.get('L1_START_BLOCK_NUMBER');
    }
    if (!l2_sent_block_number) {
      l2_sent_block_number =
        (await this.l2IngestionService.getSentEventsBlockNumber()) ||
        this.configService.get('L2_START_BLOCK_NUMBER');
    }
    if (!l2_relayed_block_number) {
      l2_relayed_block_number =
        (await this.l2IngestionService.getRelayedEventsBlockNumber()) ||
        this.configService.get('L2_START_BLOCK_NUMBER');
    }
    if (!txn_batch_block_number) {
      txn_batch_block_number =
        (await this.l1IngestionService.getTxnBatchBlockNumber()) ||
        this.configService.get('L1_START_BLOCK_NUMBER');
    }
    if (!state_batch_block_number) {
      state_batch_block_number =
        (await this.l1IngestionService.getStateBatchBlockNumber()) ||
        this.configService.get('L1_START_BLOCK_NUMBER');
    }
    await this.cacheManager.set(L1_SENT, Number(l1_sent_block_number), {
      ttl: 0,
    });
    await this.cacheManager.set(L1_RELAYED, Number(l1_relayed_block_number), {
      ttl: 0,
    });
    await this.cacheManager.set(L2_SENT, Number(l2_sent_block_number), {
      ttl: 0,
    });
    await this.cacheManager.set(L2_RELAYED, Number(l2_relayed_block_number), {
      ttl: 0,
    });
    await this.cacheManager.set(TXN_BATCH, Number(txn_batch_block_number), {
      ttl: 0,
    });
    await this.cacheManager.set(STATE_BATCH, Number(state_batch_block_number), {
      ttl: 0,
    });
    console.log('================end init cache================');
  }
  @Interval(2000)
  async l1_sent() {
    let end = 0;
    const currentBlockNumber =
      await this.l1IngestionService.getCurrentBlockNumber();
    console.log('l1 sent currentBlockNumber: ', currentBlockNumber);
    const start = Number(await this.cacheManager.get(L1_SENT));
    if (currentBlockNumber - start > SYNC_STEP) {
      end = start + SYNC_STEP;
    } else {
      end =
        start - SYNC_STEP > currentBlockNumber
          ? start - SYNC_STEP
          : currentBlockNumber;
    }
    if (currentBlockNumber > start + 1) {
      const result = await this.l1IngestionService.createSentEvents(
        start + 1,
        end,
      );
      if (result.length > 0) {
        this.logger.log(
          `sync [${result.length}] l1_sent_message_events from block [${start}] to [${end}]`,
        );
      } else {
        this.logger.log(
          `sync l1_sent_message_events from block [${start}] to [${end}]`,
        );
      }
      await this.cacheManager.set(L1_SENT, end, { ttl: 0 });
    } else {
      this.logger.log(
        `sync l1_sent finished and latest block number is: ${currentBlockNumber}`,
      );
    }
  }
  @Interval(2000)
  async l1_relayed() {
    let end = 0;
    const currentBlockNumber =
      await this.l1IngestionService.getCurrentBlockNumber();
    console.log('l1 relayed currentBlockNumber: ', currentBlockNumber);
    const start = Number(await this.cacheManager.get(L1_RELAYED));
    if (currentBlockNumber - start > SYNC_STEP) {
      end = start + SYNC_STEP;
    } else {
      end =
        start - SYNC_STEP > currentBlockNumber
          ? start - SYNC_STEP
          : currentBlockNumber;
    }
    if (currentBlockNumber > start + 1) {
      const result = await this.l1IngestionService.createRelayedEvents(
        start + 1,
        end,
      );
      if (result.length > 0) {
        this.logger.log(
          `sync [${result.length}] l1_relayed_message_events from block [${start}] to [${end}]`,
        );
      } else {
        this.logger.log(
          `sync l1_relayed_message_events from block [${start}] to [${end}]`,
        );
      }
      await this.cacheManager.set(L1_RELAYED, end, { ttl: 0 });
    } else {
      this.logger.log(
        `sync l1_relayed finished and latest block number is: ${currentBlockNumber}`,
      );
    }
  }
  @Interval(2000)
  async l2_sent() {
    let end = 0;
    const currentBlockNumber =
      await this.l2IngestionService.getCurrentBlockNumber();
    console.log('l2 sent currentBlockNumber: ', currentBlockNumber);
    const start = Number(await this.cacheManager.get(L2_SENT));
    if (currentBlockNumber - start > SYNC_STEP) {
      end = start + SYNC_STEP;
    } else {
      end =
        start - SYNC_STEP > currentBlockNumber
          ? start - SYNC_STEP
          : currentBlockNumber;
    }
    if (currentBlockNumber > start + 1) {
      const result = await this.l2IngestionService.createSentEvents(
        start + 1,
        end,
      );
      if (result.length > 0) {
        this.logger.log(
          `sync [${result.length}] l2_sent_message_events from block [${start}] to [${end}]`,
        );
      } else {
        this.logger.log(
          `sync l2_sent_message_events from block [${start}] to [${end}]`,
        );
      }
      await this.cacheManager.set(L2_SENT, end, { ttl: 0 });
    } else {
      this.logger.log(
        `sync l2_sent finished and latest block number is: ${currentBlockNumber}`,
      );
    }
  }
  @Interval(2000)
  async l2_relayed() {
    let end = 0;
    const currentBlockNumber =
      await this.l2IngestionService.getCurrentBlockNumber();
    console.log('l2 relayed currentBlockNumber: ', currentBlockNumber);
    const start = Number(await this.cacheManager.get(L2_RELAYED));
    if (currentBlockNumber - start > SYNC_STEP) {
      end = start + SYNC_STEP;
    } else {
      end =
        start - SYNC_STEP > currentBlockNumber
          ? start - SYNC_STEP
          : currentBlockNumber;
    }
    if (currentBlockNumber > start + 1) {
      const result = await this.l2IngestionService.createRelayedEvents(
        start + 1,
        end,
      );
      if (result.length > 0) {
        this.logger.log(
          `sync [${result.length}] l2_relayed_message_events from block [${start}] to [${end}]`,
        );
      } else {
        this.logger.log(
          `sync l2_relayed_message_events from block [${start}] to [${end}]`,
        );
      }
      await this.cacheManager.set(L2_RELAYED, end, { ttl: 0 });
    } else {
      this.logger.log(
        `sync l2_relayed finished and latest block number is: ${currentBlockNumber}`,
      );
    }
  }
  @Interval(2000)
  async state_batch() {
    let end = 0;
    const currentBlockNumber =
      await this.l1IngestionService.getCurrentBlockNumber();
    console.log('state batch currentBlockNumber: ', currentBlockNumber);
    const start = Number(await this.cacheManager.get(STATE_BATCH));
    if (currentBlockNumber - start > SYNC_STEP) {
      end = start + SYNC_STEP;
    } else {
      end =
        start - SYNC_STEP > currentBlockNumber
          ? start - SYNC_STEP
          : currentBlockNumber;
    }
    if (currentBlockNumber >= start + 1) {
      const result = await this.l1IngestionService.createStateBatchesEvents(
        start + 1,
        end,
      );
      if (result.length > 0) {
        this.logger.log(
          `sync [${result.length}] state batch from block [${start}] to [${end}]`,
        );
      } else {
        this.logger.log(`sync state_batch from block [${start}] to [${end}]`);
      }
      await this.cacheManager.set(STATE_BATCH, end, { ttl: 0 });
    } else {
      this.logger.log(
        `sync state_batch finished and latest block number is: ${currentBlockNumber}`,
      );
    }
  }
  @Interval(2000)
  async txn_batch() {
    let end = 0;
    const currentBlockNumber =
      await this.l1IngestionService.getCurrentBlockNumber();
    console.log('txn batch currentBlockNumber: ', currentBlockNumber);
    const start = Number(await this.cacheManager.get(TXN_BATCH));
    if (currentBlockNumber - start > SYNC_STEP) {
      end = start + SYNC_STEP;
    } else {
      end =
        start - SYNC_STEP > currentBlockNumber
          ? start - SYNC_STEP
          : currentBlockNumber;
    }
    if (currentBlockNumber >= start + 1) {
      const result = await this.l1IngestionService.createTxnBatchesEvents(
        start + 1,
        end,
      );
      if (result.length > 0) {
        this.logger.log(
          `sync [${result.length}] txn batch from block [${start}] to [${end}]`,
        );
      } else {
        this.logger.log(`sync txn_batch from block [${start}] to [${end}]`);
      }
      await this.cacheManager.set(TXN_BATCH, end, { ttl: 0 });
    } else {
      this.logger.log(
        `sync txn_batch finished and latest block number is: ${currentBlockNumber}`,
      );
    }
  }
  @Interval(2000)
  async l1l2_merge() {
    try {
      this.logger.log(`l1l2_merge to l1_to_l2 table`);
      await this.l1IngestionService.createL1L2Relation();
    } catch (error) {
      this.logger.error(`error l1l2 [handle_L1_l2_merge]: ${error}`);
    }
  }
  @Interval(2000)
  async l2l1_merge() {
    try {
      this.logger.log(`l2l1_merge to l2_to_l1 table`);
      await this.l1IngestionService.createL2L1Relation();
    } catch (error) {
      this.logger.error(`error l1l2 [handle_l1_l2__merge]: ${error}`);
    }
  }
  @Interval(2000)
  async l2l1_merge_waiting() {
    try {
      this.logger.log(`l2l1_merge_waiting to l2_to_l1 table`);
      await this.l1IngestionService.handleWaitTransaction();
    } catch (error) {
      this.logger.error(`error l1l2 [handle_l2l1_merge_waiting]: ${error}`);
    }
  }

  // @Interval(2000)
  // async update_transactions() {
  //   try {
  //     this.logger.log(`update l1_origin_tx_hash to transactions table`);
  //     await this.l1IngestionService.updateL1OriginTxHashInTransactions();
  //   } catch (error) {
  //     this.logger.error(`error [update_transactions]: ${error}`);
  //   }
  // }
}
