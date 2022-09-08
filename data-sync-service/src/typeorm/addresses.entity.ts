import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity()
export class Addresses {
  @PrimaryColumn({ type: "bytea", name: 'hash' })
  hash: string;

  @Column({ type: 'bytea', nullable: true })
  contract_code: string;

  @Column({ type: 'timestamp', default: () => "CURRENT_TIMESTAMP"})
  inserted_at: Date;

  @Column({ type: 'timestamp', default: () => "CURRENT_TIMESTAMP"})
  updated_at: Date;
  
}