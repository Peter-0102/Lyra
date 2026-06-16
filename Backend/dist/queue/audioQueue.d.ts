import { Queue } from 'bullmq';
export declare const AUDIO_QUEUE_NAME = "audio-extraction";
export declare function getAudioQueue(): Queue;
export declare function closeAudioQueue(): Promise<void>;
//# sourceMappingURL=audioQueue.d.ts.map