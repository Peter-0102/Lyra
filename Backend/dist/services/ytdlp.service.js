import { spawn } from 'node:child_process';
export function runYtDlp(args, options = {}) {
    return new Promise((resolve, reject) => {
        const child = spawn('yt-dlp', args, {
            stdio: ['ignore', 'pipe', 'pipe'],
        });
        let stdout = '';
        let stderr = '';
        let timedOut = false;
        const timeout = options.timeoutMs ?? 5 * 60 * 1000;
        const timer = setTimeout(() => {
            timedOut = true;
            child.kill('SIGTERM');
        }, timeout);
        child.stdout?.on('data', (data) => {
            const text = data.toString();
            console.log(`[YT-DLP STDOUT]: ${text.trim()}`);
            stdout += text;
            if (options.onProgress) {
                const progressMatch = text.match(/\[download\]\s+(\d+\.?\d*)%/);
                if (progressMatch) {
                    const pct = parseFloat(progressMatch[1]);
                    console.log(`[YT-DLP PROGRESS]: ${pct}%`);
                    options.onProgress(pct);
                }
            }
        });
        child.stderr?.on('data', (data) => {
            const text = data.toString();
            console.log(`[YT-DLP STDERR]: ${text.trim()}`);
            stderr += text;
        });
        child.on('close', (exitCode) => {
            clearTimeout(timer);
            if (timedOut) {
                reject(new Error('yt-dlp process timed out'));
                return;
            }
            resolve({ exitCode: exitCode ?? 1, stdout, stderr });
        });
        child.on('error', (err) => {
            clearTimeout(timer);
            reject(err);
        });
    });
}
export function parseYtDlpError(stderr) {
    if (stderr.includes('Video unavailable')) {
        return 'Este video ya no está disponible';
    }
    if (stderr.includes('Private video')) {
        return 'Este video es privado';
    }
    if (stderr.includes('Sign in to confirm your age')) {
        return 'Video con restricción de edad, no se puede descargar';
    }
    if (stderr.includes('This live event')) {
        return 'No se pueden descargar transmisiones en vivo';
    }
    if (stderr.includes('HTTP Error 403')) {
        return 'Video restringido, no se puede acceder';
    }
    if (stderr.includes('Unable to extract')) {
        return 'No se pudo extraer la información del video';
    }
    return 'Error desconocido al procesar el video';
}
export function buildAudioExtractionArgs(videoId, outputTemplate) {
    return [
        '-f', 'bestaudio[ext=m4a]/bestaudio[ext=webm]/bestaudio/best',
        '--no-playlist',
        '--no-warnings',
        '--print-json',
        '--progress',
        '--newline',
        '--extractor-args', 'youtube:player_client=web,default',
        '-o', outputTemplate,
        `https://www.youtube.com/watch?v=${videoId}`,
    ];
}
//# sourceMappingURL=ytdlp.service.js.map