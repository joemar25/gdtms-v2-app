/**
 * Pagination wrapper — matches Laravel LengthAwarePaginator JSON
 */

export interface PaginatedResponse<T> {
    data: T[];
    current_page: number;
    last_page: number;
    total: number;
    per_page: number;
    from?: number;
    to?: number;
}
