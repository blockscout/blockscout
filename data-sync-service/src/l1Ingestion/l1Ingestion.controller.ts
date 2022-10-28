import { L1IngestionService } from './l1Ingestion.service';
import { Controller, Get } from '@nestjs/common';

@Controller('/')
export class L1IngestionController {
  constructor(private readonly l1IngestionService: L1IngestionService) {}

  @Get('l1tol2')
  getL1ToL2Relation() {
    return this.l1IngestionService.getL1ToL2Relation();
  }
  @Get('l2tol1')
  getL2ToL1Relation() {
    return this.l1IngestionService.getL2ToL1Relation();
  }
}