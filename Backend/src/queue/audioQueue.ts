import { Queue } from 'bullmq';
import { getRedisConnection } from './connection.js';
import { config } from '../config.js';

export const AUDIO_QUEUE_NAME = 'audio-extraction';

let audioQueue: Queue | null = null;

export function getAudioQueue(): Queue {
  if (!audioQueue) {
    audioQueue = new Queue(AUDIO_QUEUE_NAME, {
      connection: getRedisConnection() as any,
      defaultJobOptions: {
        attempts: 4,
        backoff: {
          type: 'exponential',
          delay: 10000,
        },
        removeOnComplete: {
          age: 24 * 3600,
          count: 100,
        },
        removeOnFail: {
          age: 7 * 24 * 3600,
        },
      },
    });
  }
  return audioQueue;
}

export async function closeAudioQueue(): Promise<void> {
  if (audioQueue) {
    await audioQueue.close();
    audioQueue = null;
  }
}
