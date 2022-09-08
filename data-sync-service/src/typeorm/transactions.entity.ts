import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity()
export class Transactions {
  @PrimaryColumn({ type: "bytea", name: 'hash' })
  hash: Buffer;

  @Column({ type: 'timestamp', default: () => "CURRENT_TIMESTAMP"})
  inserted_at: Date;

  @Column({ type: 'timestamp', default: () => "CURRENT_TIMESTAMP"})
  updated_at: Date;
  
}