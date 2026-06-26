interface FavoriteRow {
    id: string;
    user_id: string;
    song_id: string;
    title: string | null;
    artist: string | null;
    file_path: string | null;
    duration: number | null;
    thumbnail: string | null;
    created_at: number;
}
interface PlaylistRow {
    id: string;
    user_id: string;
    name: string;
    description: string | null;
    songs: unknown[];
    created_at: number;
    updated_at: number;
}
export declare function replaceFavorites(userId: string, favorites: Array<{
    songId: string;
    title?: string;
    artist?: string;
    filePath?: string;
    duration?: number;
    thumbnail?: string;
}>, now: number): Promise<void>;
export declare function getFavorites(userId: string): Promise<FavoriteRow[]>;
export declare function replacePlaylists(userId: string, playlists: Array<{
    id?: string;
    name: string;
    description?: string;
    songs?: unknown[];
}>, now: number): Promise<void>;
export declare function getPlaylists(userId: string): Promise<PlaylistRow[]>;
export {};
//# sourceMappingURL=sync.repository.d.ts.map