import emptyAnim from '@/anim/empty.json';
import notFoundAnim from '@/anim/not-found.json';
import Lottie from 'lottie-react';

type AnimationType = 'empty' | 'not-found';

const ANIM_MAP = {
    empty: emptyAnim,
    'not-found': notFoundAnim,
} as const;

interface EmptyStateProps {
    message?: string;
    animation?: AnimationType;
}

export default function EmptyState({ message = 'Nothing here yet.', animation = 'empty' }: EmptyStateProps) {
    return (
        <div className="flex flex-col items-center justify-center px-8 py-16 text-center">
            <div className="h-48 w-48">
                <Lottie animationData={ANIM_MAP[animation]} loop />
            </div>
            <p className="mt-4 text-sm text-slate-500">{message}</p>
        </div>
    );
}
