import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  const config = new DocumentBuilder()
    .setTitle('Data Sync Service with Postgres')
    .setVersion('1.0')
    .addTag('data-sync-service')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api', app, document);
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  app.use(require('express-status-monitor')());
  await app.listen(3000);
}
bootstrap();
