export interface YtDlpResult {
    exitCode: number;
    stdout: string;
    stderr: string;
}
export interface YtDlpOptions {
    onProgress?: (percentage: number) => void;
    timeoutMs?: number;
}
export declare function runYtDlp(args: string[], options?: YtDlpOptions): Promise<YtDlpResult>;
export declare function parseYtDlpError(stderr: string): string;
export declare function buildAudioExtractionArgs(videoId: string, outputTemplate: string): string[];
//# sourceMappingURL=ytdlp.service.d.ts.map