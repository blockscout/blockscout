import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity()
export class Transactions {
  @PrimaryColumn({ type: 'bytea', name: 'hash' })
  hash: string;

  @Column({ type: 'bigint' })
  eigen_txn_batch_index: number;

  @Column({ type: 'bytea' })
  eigen_submission_tx_hash: string;

  @Column({ type: 'bigint' })
  l1_state_batch_index: number;

  @Column({ type: 'bytea' })
  l1_state_root_submission_tx_hash: string;

  @Column({ type: 'bytea' })
  l1_origin_tx_hash: string;

  @Column({ type: 'int4' })
  block_number: number;

  @Column({ type: 'numeric', precision: 100 })
  l1_gas_price: number;

  @Column({ type: 'numeric', precision: 100 })
  l1_gas_used: number;

  @Column({ type: 'numeric', precision: 100 })
  l1_fee: number;

  @Column({ type: 'numeric', precision: 10, scale: 2 })
  l1_fee_scalar: number;
}
