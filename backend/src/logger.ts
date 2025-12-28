import pino, { LoggerOptions } from 'pino';
import { config } from './config';

export const loggerOptions: LoggerOptions = {
  level: config.logLevel,
  transport:
    config.env === 'development'
      ? { target: 'pino-pretty', options: { colorize: true } }
      : undefined,
};

export const logger = pino(loggerOptions);
