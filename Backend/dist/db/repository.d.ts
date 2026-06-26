import type { AudioJob, JobStatus } from '../types/audio.types.js';
export declare function createJob(job: AudioJob): Promise<void>;
export declare function updateStatus(id: string, status: JobStatus, extra?: Partial<Pick<AudioJob, 'file_path' | 'file_size' | 'format' | 'error_message' | 'title' | 'artist' | 'duration_sec' | 'expires_at' | 'progress'>>): Promise<void>;
export declare function findByJobId(id: string): Promise<AudioJob | undefined>;
export declare function findLatestReadyByVideoId(videoId: string): Promise<AudioJob | undefined>;
export declare function findLatestInFlightByVideoId(videoId: string): Promise<AudioJob | undefined>;
export declare function findExpired(now: number): Promise<AudioJob[]>;
export declare function markDeleted(id: string): Promise<void>;
//# sourceMappingURL=repository.d.ts.map