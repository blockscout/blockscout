import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { AddressController } from './address.controller';
import { AddressService } from './address.service';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Addresses } from 'src/typeorm';
import { Transactions } from 'src/typeorm';


@Module({
  imports: [
    TypeOrmModule.forFeature([Addresses, Transactions]),
    HttpModule
  ],
  controllers: [AddressController],
  providers: [AddressService]
})
export class AddressModule {}
