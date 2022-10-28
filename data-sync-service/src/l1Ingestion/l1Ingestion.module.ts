import { Module } from '@nestjs/common';
import { L1IngestionService } from './l1Ingestion.service';
import { L1IngestionController } from './l1Ingestion.controller';
import { L2IngestionModule } from './../l2Ingestion/l2Ingestion.module';
import { TypeOrmModule } from '@nestjs/typeorm';
import { 
  L1RelayedMessageEvents,
  L1SentMessageEvents,
} from 'src/typeorm';

@Module({
  imports: [
    L2IngestionModule,
    TypeOrmModule.forFeature([
      L1RelayedMessageEvents,
      L1SentMessageEvents,
    ])
  ],
  controllers: [L1IngestionController],
  providers: [L1IngestionService],
  exports: [L1IngestionService]
})
export class L1IngestionModule {}
