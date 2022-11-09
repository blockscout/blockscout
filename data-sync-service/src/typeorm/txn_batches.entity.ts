import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity()
export class TxnBatches {
  @Column({ type: 'bigint' })
  batch_index: number;

  @Column({ type: 'bigint' })
  block_number: string;

  @PrimaryColumn({ type: 'bytea', name: 'hash' })
  hash: string;

  @Column({ type: 'bigint' })
  size: number;

  @Column({ type: 'bigint' })
  l1_block_number: number;

  @Column({ type: 'bigint' })
  batch_root: string;

  @Column({ type: 'bigint' })
  extra_data: string;

  @Column({ type: 'bigint' })
  pre_total_elements: number;

  @Column({ type: 'timestamp' })
  timestamp: Date;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  inserted_at: Date;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  updated_at: Date;
}
