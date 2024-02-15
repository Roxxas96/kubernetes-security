import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { exec } from 'child_process';
import { Repository } from 'typeorm';
import { Echo } from './echo.entity';

@Injectable()
export class AppService {
  constructor(
    @InjectRepository(Echo)
    private echoRepository: Repository<Echo>,
  ) {}

  getHello(): string {
    return 'Hello World!';
  }

  sendMessage(message: string): Promise<string> {
    return new Promise((resolve, reject) => {
      exec(`echo ${message}`, (error, stdout, stderr) => {
        if (error) {
          Logger.error(error);
          reject(error);
        }
        Logger.log(`stdout : ${stdout}`);
        Logger.log(`stderr : ${stderr}`);

        this.echoRepository
          .save({ message: stdout })
          .then((echo) => {
            resolve(echo.message);
          })
          .catch((err) => {
            Logger.error(err);
            reject(err);
          });
      });
    });
  }
}
