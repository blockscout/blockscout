import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity()
export class TxnBatches {
  @PrimaryColumn({ type: 'bytea', name: 'hash' })
  hash: string;

  @PrimaryColumn({ type: 'int8' })
  batch: number;

  @PrimaryColumn({ type: 'int8' })
  size: number;

  @PrimaryColumn({ type: 'int8' })
  index: number;

  @Column({ type: 'numeric', precision: 100 })
  pre_total_elements: number;
  
  @Column({ type: 'timestamp' })
  timestamp: Date;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP'})
  inserted_at: Date;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP'})
  updated_at: Date;
  
}