
import { Injectable, Logger, Inject, CACHE_MANAGER } from '@nestjs/common';
import { Cache } from 'cache-manager';
import { Cron, Interval, Timeout } from '@nestjs/schedule';
import { L1IngestionService } from './../l1Ingestion/l1Ingestion.service';
import { L2IngestionService } from './../l2Ingestion/l2Ingestion.service';
import { ConfigService } from '@nestjs/config';

const L1_SENT = 'l1_sent_block_number';
const L1_RELAYED = 'l1_relayed_block_number';
const L2_SENT = 'l2_sent_block_number';
const L2_RELAYED = 'l2_relayed_block_number';

@Injectable()
export class TasksService {
  constructor(
    private configService: ConfigService,
    private readonly l1IngestionService: L1IngestionService,
    private readonly l2IngestionService: L2IngestionService,
    @Inject(CACHE_MANAGER) private cacheManager: Cache
  ) {
    this.initCache();
  }
  private readonly logger = new Logger(TasksService.name);

  async initCache() {
    let l1_sent_block_number = await this.cacheManager.get(L1_SENT);
    let l1_relayed_block_number = await this.cacheManager.get(L1_RELAYED);
    let l2_sent_block_number = await this.cacheManager.get(L2_SENT);
    let l2_relayed_block_number = await this.cacheManager.get(L2_RELAYED);
    if (!l1_sent_block_number) {
      l1_sent_block_number = await this.l1IngestionService.getSentEventsBlockNumber() || this.configService.get('L1_START_BLOCK_NUMBER');
    }
    if (!l1_relayed_block_number) {
      l1_relayed_block_number = await this.l1IngestionService.getRelayedEventsBlockNumber() || this.configService.get('L1_START_BLOCK_NUMBER');
    }
    if (!l2_sent_block_number) {
      l2_sent_block_number = await this.l2IngestionService.getSentEventsBlockNumber() || this.configService.get('L2_START_BLOCK_NUMBER');
    }
    if (!l2_relayed_block_number) {
      l2_relayed_block_number = await this.l2IngestionService.getRelayedEventsBlockNumber() || this.configService.get('L2_START_BLOCK_NUMBER');
    }
    await this.cacheManager.set(L1_SENT, Number(l1_sent_block_number), { ttl: 0 });
    await this.cacheManager.set(L1_RELAYED, Number(l1_relayed_block_number), { ttl: 0 });
    await this.cacheManager.set(L2_SENT, Number(l2_sent_block_number), { ttl: 0 });
    await this.cacheManager.set(L2_RELAYED, Number(l2_relayed_block_number), { ttl: 0 });
    console.log('================end init cache================')
  }
  @Interval(10000)
  async l1_sent() {
    try {
      const currentBlockNumber = await this.l1IngestionService.getCurrentBlockNumber();
      console.log('l1 currentBlockNumber: ', currentBlockNumber);
      const start = Number(await this.cacheManager.get(L1_SENT));
      const end = Math.min(start + 10, currentBlockNumber);
      const result = await this.l1IngestionService.createSentEvents(start, end);
      if (result.length > 0) {
        this.logger.log(`sync [${result.length}] l1_sent_message_events from block [${start}] to [${end}]`)
      }
      await this.cacheManager.set(L1_SENT, end);
    } catch (error) {
      this.logger.error(`error l1 [handle_sync_l1_sent_message_events]: ${error}`);
    }
  }
  @Interval(10000)
  async l1_relayed() {
    try {
      const currentBlockNumber = await this.l1IngestionService.getCurrentBlockNumber();
      const start = Number(await this.cacheManager.get(L1_RELAYED));
      const end = Math.min(start + 10, currentBlockNumber);
      const result = await this.l1IngestionService.createRelayedEvents(start, end);
      if (result.length > 0) {
        this.logger.log(`sync [${result.length}] l1_relayed_message_events from block [${start}] to [${end}]`)
      }
      await this.cacheManager.set(L1_RELAYED, end);
    } catch (error) {
      this.logger.error(`error l1 [handle_sync_l1_relayed_message_events]: ${error}`);
    }
  }
  @Interval(10000)
  async l2_sent() {
    try {
      const currentBlockNumber = await this.l2IngestionService.getCurrentBlockNumber();
      console.log('l2 currentBlockNumber: ', currentBlockNumber);
      const start = Number(await this.cacheManager.get(L2_SENT));
      const end = Math.min(start + 10, currentBlockNumber);
      const result = await this.l2IngestionService.createSentEvents(start, end);
      if (result.length > 0) {
        this.logger.log(`sync [${result.length}] l2_sent_message_events from block [${start}] to [${end}]`)
      }
      await this.cacheManager.set(L2_SENT, end);
    } catch (error) {
      this.logger.error(`error l2 [handle_sync_l2_sent_message_events]: ${error}`);
    }
  }
  @Interval(10000)
  async l2_relayed() {
    try {
      const currentBlockNumber = await this.l2IngestionService.getCurrentBlockNumber();
      const start = Number(await this.cacheManager.get(L2_RELAYED));
      const end = Math.min(start + 10, currentBlockNumber);
      const result = await this.l2IngestionService.createRelayedEvents(start, end);
      if (result.length > 0) {
        this.logger.log(`sync [${result.length}] l2_relayed_message_events from block [${start}] to [${end}]`)
      }
      await this.cacheManager.set(L2_RELAYED, end);
    } catch (error) {
      this.logger.error(`error l2 [handle_sync_l2_relayed_message_events]: ${error}`);
    }
  }
  @Interval(10000)
  async state_batch() {
    try {
      const currentBlockNumber = await this.l1IngestionService.getCurrentBlockNumber();
      const start = Number(await this.cacheManager.get(L1_RELAYED));
      const end = Math.min(start + 10, currentBlockNumber);
      const result = await this.l1IngestionService.createStateBatchesEvents(start, end);
      if (result.length > 0) {
        this.logger.log(`sync [${result.length}] createStateBatchesEvents from block [${start}] to [${end}]`)
      }
      await this.cacheManager.set(L1_RELAYED, end);
    } catch (error) {
      this.logger.error(`error l2 [state_batch]: ${error}`);
    }
  }

  @Interval(10000)
  async txn_batch() {
    try {
      const currentBlockNumber = await this.l1IngestionService.getCurrentBlockNumber();
      const start = Number(await this.cacheManager.get(L1_RELAYED));
      const end = Math.min(start + 10, currentBlockNumber);
      const result = await this.l1IngestionService.createTxnBatchesEvents(start, end);
      if (result.length > 0) {
        this.logger.log(`sync [${result.length}] createStateBatchesEvents from block [${start}] to [${end}]`)
      }
      await this.cacheManager.set(L1_RELAYED, end);
    } catch (error) {
      this.logger.error(`error l2 [state_batch]: ${error}`);
    }
  }

  @Interval(10000)
  async l1l2_merge() {
    try {
      await this.l1IngestionService.createL1L2Relation();
    } catch (error) {
      this.logger.error(`error l1l2 [handle_L1_l2_merge]: ${error}`);
    }
  }

  @Interval(10000)
  async l2l1_merge() {
    try {
      await this.l1IngestionService.createL2L1Relation();
    } catch (error) {
      this.logger.error(`error l1l2 [handle_l1l2_tx_status]: ${error}`);
    }
  }
}
