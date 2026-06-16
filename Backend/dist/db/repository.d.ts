import type { AudioJob, JobStatus } from '../types/audio.types.js';
export declare function createJob(job: AudioJob): void;
export declare function updateStatus(id: string, status: JobStatus, extra?: Partial<Pick<AudioJob, 'file_path' | 'file_size' | 'format' | 'error_message' | 'title' | 'artist' | 'duration_sec' | 'expires_at' | 'progress'>>): void;
export declare function findByJobId(id: string): AudioJob | undefined;
export declare function findLatestReadyByVideoId(videoId: string): AudioJob | undefined;
export declare function findExpired(now: number): AudioJob[];
export declare function markDeleted(id: string): void;
//# sourceMappingURL=repository.d.ts.map