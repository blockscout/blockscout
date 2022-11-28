import { Module } from '@nestjs/common';
import { L2IngestionService } from './l2Ingestion.service';
import { TypeOrmModule } from '@nestjs/typeorm';
import { L2RelayedMessageEvents, L2SentMessageEvents } from 'src/typeorm';

@Module({
  imports: [
    TypeOrmModule.forFeature([L2RelayedMessageEvents, L2SentMessageEvents]),
  ],
  providers: [L2IngestionService],
  exports: [L2IngestionService],
})
export class L2IngestionModule {}
