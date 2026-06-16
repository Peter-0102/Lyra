import { Queue } from 'bullmq';
import { getRedisConnection } from './connection.js';
export const AUDIO_QUEUE_NAME = 'audio-extraction';
let audioQueue = null;
export function getAudioQueue() {
    if (!audioQueue) {
        audioQueue = new Queue(AUDIO_QUEUE_NAME, {
            connection: getRedisConnection(),
            defaultJobOptions: {
                attempts: 2,
                backoff: {
                    type: 'exponential',
                    delay: 5000,
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
export async function closeAudioQueue() {
    if (audioQueue) {
        await audioQueue.close();
        audioQueue = null;
    }
}
//# sourceMappingURL=audioQueue.js.map