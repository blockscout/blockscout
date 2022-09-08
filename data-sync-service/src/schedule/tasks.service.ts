import { Injectable, Logger } from '@nestjs/common';
import { Cron, Interval, Timeout } from '@nestjs/schedule';

@Injectable()
export class TasksService {
  private readonly logger = new Logger(TasksService.name);

  @Cron('45 * * * * *')
  handleCron() {
    this.logger.debug('will load in 45 secs');
  }

  @Interval(10000)
  handleInterval() {
    this.logger.debug('2');
  }

  @Timeout(5000)
  handleTimeout() {
    this.logger.debug('3');
  }
}