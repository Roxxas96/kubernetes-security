import { Repository } from 'typeorm';
import { Echo } from './echo.entity';
export declare class AppService {
    private echoRepository;
    constructor(echoRepository: Repository<Echo>);
    getHello(): string;
    sendMessage(message: string): Promise<string>;
}
