export type JobStatus = 'queued' | 'processing' | 'ready' | 'error';

export interface AudioJob {
  id: string;
  video_id: string;
  user_id: string | null;
  status: JobStatus;
  file_path: string | null;
  file_size: number | null;
  format: string | null;
  error_message: string | null;
  title: string | null;
  artist: string | null;
  duration_sec: number | null;
  progress: number | null;
  created_at: number;
  updated_at: number;
  expires_at: number;
}

export interface RequestAudioBody {
  videoId: string;
}

export interface RequestAudioResponse {
  jobId: string;
  status: JobStatus;
  videoId: string;
  title?: string;
  artist?: string;
  durationSec?: number;
  fileSize?: number;
  format?: string;
}

export interface StatusResponse {
  jobId: string;
  status: JobStatus;
  progress?: number;
  title?: string;
  artist?: string;
  durationSec?: number;
  fileSize?: number;
  format?: string;
  errorMessage?: string;
}

export interface HealthResponse {
  status: 'ok' | 'degraded';
  redis: boolean;
  database: boolean;
  ytDlp: boolean;
  ytDlpVersion?: string;
}
