import successAnim from '@/anim/successfully-done.json';
import Lottie from 'lottie-react';

interface SuccessOverlayProps {
    visible: boolean;
    message?: string;
    onDone?: () => void;
}

export default function SuccessOverlay({ visible, message = 'Done!', onDone }: SuccessOverlayProps) {
    if (!visible) return null;
    return (
        <div className="fixed inset-0 z-50 flex flex-col items-center justify-center bg-white">
            <div className="h-52 w-52">
                <Lottie animationData={successAnim} loop={false} onComplete={onDone} />
            </div>
            <p className="mt-4 text-base font-semibold text-slate-900">{message}</p>
        </div>
    );
}
