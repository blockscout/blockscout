import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Addresses } from 'src/typeorm';
import { Transactions } from 'src/typeorm';
import { Repository, getManager, EntityManager } from 'typeorm';
import Web3 from 'web3';

@Injectable()
export class AddressService {
  entityManager: EntityManager;
  constructor(
    @InjectRepository(Addresses) private readonly addressRepository: Repository<Addresses>,
    @InjectRepository(Transactions) private readonly TxRepository: Repository<Transactions>,
  ) {
    this.entityManager = getManager();
  }

  getAddresses() {
    return this.addressRepository.find();
  }
  async getTxs() {
    const result = await this.TxRepository.find();
    const _r = []
    for(let item of result) {
      const hash = item.hash.toString('hex')
      _r.push({
        hash: '0x' + hash,
        inserted_at: item.inserted_at,
        updated_at: item.updated_at
      })
    }
    console.log('length:', _r.length)
    return _r;
  }
  async getPastLogs() {
    const web3 = new Web3(
      new Web3.providers.HttpProvider(
        'https://eth-mainnet.g.alchemy.com/v2/U_anqpCXVm70-4kEJ8FPbAHfhSOQW8Zd'
      )
    );
    const result = await web3.eth.getPastLogs({
      fromBlock: 15483081,
      toBlock: 'latest',
      address: '0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1'
    })
    return result;
  }
}
