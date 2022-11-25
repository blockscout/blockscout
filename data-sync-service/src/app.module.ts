import { TasksModule } from './schedule/tasks.module';
import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import entities from './typeorm';
import { ScheduleModule } from '@nestjs/schedule';
import { L1IngestionModule } from './l1Ingestion/l1Ingestion.module';
import { L2IngestionModule } from './l2Ingestion/l2Ingestion.module';
import { StatusMonitorModule } from 'nest-status-monitor';
import statusMonitorConfig from './config/statusMonitor';

@Module({
  imports: [
    StatusMonitorModule.setUp(statusMonitorConfig),
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        host: configService.get('DB_HOST'),
        port: +configService.get<number>('DB_PORT'),
        username: configService.get('DB_USERNAME'),
        password: configService.get('DB_PASSWORD'),
        database: configService.get('DB_NAME'),
        entities: entities,
        synchronize: false,
      }),
      inject: [ConfigService],
    }),
    ScheduleModule.forRoot(),
    TasksModule,
    L1IngestionModule,
    L2IngestionModule,
  ],
  controllers: [],
  providers: [],
})
export class AppModule {}
