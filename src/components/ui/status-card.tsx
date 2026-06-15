import type { ReactNode } from "react";

export function StatusCard({
  label,
  value,
  helper,
  icon,
}: {
  label: string;
  value: string | number;
  helper: string;
  icon: ReactNode;
}) {
  return (
    <section className="min-h-[86px] rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]">
      <div className="flex items-center justify-between gap-3">
        <p className="text-sm font-medium text-[#52625b]">{label}</p>
        <span className="grid h-8 w-8 place-items-center rounded-md bg-[#eef4ef] text-[#184f3c]">
          {icon}
        </span>
      </div>
      <div className="mt-2 flex items-end gap-2">
        <strong className="text-3xl font-semibold tracking-normal text-[#14231c]">
          {value}
        </strong>
        <span className="pb-1 text-xs text-[#6a7771]">{helper}</span>
      </div>
    </section>
  );
}
