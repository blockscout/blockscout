import { AddressService } from './address.service';
import { Controller, Get } from '@nestjs/common';

@Controller('/')
export class AddressController {
  constructor(private readonly addressService: AddressService) {}

  @Get()
  getAddresses() {
    return this.addressService.getAddresses();
  }

  @Get('tx')
  getTxs() {
    return this.addressService.getTxs();
  }

  @Get('getPastLogs')
  getPastLogs() {
    return this.addressService.getPastLogs();
  }
}
