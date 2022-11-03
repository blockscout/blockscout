import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity()
export class TxnBatches {
  @Column({ type: 'bigint' })
  batch_index: number;

  @PrimaryColumn({ type: 'bytea', name: 'hash' })
  hash: string;

  @Column({ type: 'bigint' })
  size: number;

  @Column({ type: 'bigint' })
  pre_total_elements: number;

  @Column({ type: 'timestamp' })
  timestamp: Date;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  inserted_at: Date;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  updated_at: Date;
}
