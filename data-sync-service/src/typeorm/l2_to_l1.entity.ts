import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity()
export class L2ToL1 {
  @Column({ type: 'bytea' })
  hash: string;

  @PrimaryColumn({ type: 'bytea', name: 'l2_hash' })
  l2_hash: string;

  @Column({ type: 'bytea' })
  msg_hash: string;

  @Column({ type: 'int8' })
  block: number;

  @Column({ type: 'int8' })
  msg_nonce: number;

  @Column({ type: 'bytea' })
  from_address: string;

  @Column({ type: 'timestamp' })
  timestamp: Date;

  @Column({ type: 'numeric', precision: 100 })
  gas_limit: number;

  @Column({ type: 'int8' })
  txn_batch_index: number;

  @Column({ type: 'int8' })
  state_batch_index: number;

  @Column({ type: 'varchar', length: 255 })
  status: string;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  inserted_at: Date;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  updated_at: Date;

}