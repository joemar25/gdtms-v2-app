interface LoadingOverlayProps {
    visible: boolean;
    message?: string;
}

export default function LoadingOverlay({ visible, message = 'Please wait…' }: LoadingOverlayProps) {
    if (!visible) return null;
    return (
        <div className="bg-background/95 fixed inset-0 z-50 flex flex-col items-center justify-center">
            <svg className="text-primary h-14 w-14 animate-spin" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle className="opacity-20" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="3" />
                <path className="opacity-90" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
            <p className="text-foreground mt-5 text-[14px] font-medium">{message}</p>
        </div>
    );
}
