import { useEffect } from 'react';

export interface ToastState {
  msg: string;
  ok: boolean;
  id: number;
}

export function Toast({ toast, onDone }: { toast: ToastState | null; onDone: () => void }) {
  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(onDone, 2600);
    return () => clearTimeout(t);
  }, [toast, onDone]);

  if (!toast) return null;
  return (
    <div className="pointer-events-none fixed inset-x-0 bottom-6 z-50 flex justify-center px-4">
      <div
        className={`rounded-xl px-5 py-3 text-sm font-semibold shadow-lg backdrop-blur ${
          toast.ok ? 'bg-emerald-500/90 text-black' : 'bg-rose-500/90 text-white'
        }`}
      >
        {toast.msg}
      </div>
    </div>
  );
}
