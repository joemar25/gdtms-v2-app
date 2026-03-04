/**
 * for the Handle Inertia Request:
 *
 * 'auth' => [
                'user' => $request->user(),
            ],
            'courier' => $auth->getCourier(),
            'debug' => config('app.debug'),
            'flash' => [
                'message' => $request->session()->get('message'),
                'success' => $request->session()->get('success'),
                'error' => $request->session()->get('error'),
                'info' => $request->session()->get('info'),
            ],
            ....
 */

import { Courier } from '@/types/courier';
import { Auth } from '@/types/user';

export interface SharedData {
    auth: Auth;
    courier?: Courier | null;
    debug: boolean;
    flash?: {
        message?: string | null;
        success?: string | null;
        error?: string | null;
        info?: string | null;
    };
    [key: string]: unknown;
}
