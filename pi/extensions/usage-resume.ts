import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const KEY = "usage-resume";
const BUFFER = 60_000;
const MAX_CYCLES = 3;
interface Pending { session: string; model: string; user: string; due: number }
interface State { version: 1; enabled: boolean; cycles: number; pending?: Pending }

// Only subscription-specific signals: a bare 429/rate-limit/quota error is not enough.
export function quotaReset(provider: string, text: string, now = Date.now()): number | undefined {
  if (provider !== "openai-codex" || /rate_limit_exceeded|usage_not_included|insufficient_quota|billing|invalid_api_key|unauthorized/i.test(text)) return;
  if (!/\busage[ _]limit[ _]reached\b|\b(?:ChatGPT|subscription) usage limit\b/i.test(text)) return;
  const epoch = text.match(/["']?resets_at["']?\s*:\s*(\d+(?:\.\d+)?)/i);
  const minutes = text.match(/try again in\s*~?\s*(\d+(?:\.\d+)?)\s*(?:minutes?|mins?)\b/i);
  let due = now + 5 * 60 * 60_000;
  if (epoch) {
    const value = Number(epoch[1]);
    if (Number.isFinite(value) && value > 0) due = value < 1e12 ? value * 1000 : value;
  } else if (minutes) due = now + Number(minutes[1]) * 60_000;
  return Math.max(now, due) + BUFFER;
}

export function validState(value: unknown): value is State {
  const s = value as State | undefined;
  if (!s || s.version !== 1 || typeof s.enabled !== "boolean" || !Number.isInteger(s.cycles) || s.cycles < 0 || s.cycles > MAX_CYCLES) return false;
  const p = s.pending;
  return p === undefined || (p !== null && typeof p === "object" && typeof p.session === "string" && typeof p.model === "string" && typeof p.user === "string" && Number.isFinite(p.due) && p.due > 0 && p.due <= 8.64e15);
}

export default function (pi: ExtensionAPI) {
  let state: State = { version: 1, enabled: true, cycles: 0 };
  let timer: ReturnType<typeof setTimeout> | undefined;
  let live: ExtensionContext | undefined;
  let active = false;
  const stop = () => { if (timer) clearTimeout(timer); timer = undefined; };
  const model = (ctx: ExtensionContext) => `${ctx.model?.provider}/${ctx.model?.id}`;
  const user = (ctx: ExtensionContext) => ctx.sessionManager.getBranch().filter(e => e.type === "message" && e.message.role === "user").at(-1)?.id ?? "";
  const status = () => live?.ui.setStatus(KEY, state.pending ? `usage resume ${new Date(state.pending.due).toLocaleString()} (${state.cycles}/${MAX_CYCLES})` : undefined);
  const save = () => { pi.appendEntry(KEY, { ...state }); status(); };
  const cancel = () => { stop(); state.pending = undefined; save(); };
  const matches = (ctx: ExtensionContext, p: Pending) => ctx.sessionManager.getSessionId() === p.session && model(ctx) === p.model && user(ctx) === p.user;
  const fire = () => {
    stop();
    const ctx = live, p = state.pending;
    if (!active || !ctx || ctx.mode !== "tui" || !state.enabled || !p) return;
    if (!matches(ctx, p)) { cancel(); return; }
    if (!ctx.isIdle() || ctx.hasPendingMessages()) { cancel(); ctx.ui.notify("Usage resume cancelled: agent busy or input queued.", "warning"); return; }
    if (state.cycles >= MAX_CYCLES) { cancel(); return; }
    state.pending = undefined;
    state.cycles++;
    // Persist consumption BEFORE triggering so reload cannot duplicate this attempt.
    save();
    // There is no idle ctx.continue() API. A custom message triggers a turn without
    // impersonating the user or inventing a new task.
    pi.sendMessage({ customType: KEY, content: "The subscription usage-reset wait has ended. Resume the existing unfinished task from its last state; do not repeat completed work. If it is already complete, stop.", display: true }, { triggerTurn: true });
  };
  const arm = () => {
    stop();
    if (!active || live?.mode !== "tui" || !state.enabled || !state.pending) return;
    // Chunk long waits to avoid Node's 32-bit timer overflow.
    timer = setTimeout(() => { if (state.pending && state.pending.due > Date.now()) arm(); else fire(); }, Math.min(2_147_483_647, Math.max(0, state.pending.due - Date.now())));
    timer.unref?.();
    status();
  };
  const restore = (ctx: ExtensionContext) => {
    state = { version: 1, enabled: true, cycles: 0 };
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type === "custom" && entry.customType === KEY && validState(entry.data)) state = { ...entry.data };
    }
  };
  pi.on("session_start", (_event, ctx) => {
    stop(); live = ctx; active = true;
    restore(ctx);
    if (state.pending && !matches(ctx, state.pending)) cancel();
    arm(); status();
  });
  pi.on("session_shutdown", () => { active = false; stop(); live = undefined; });
  pi.on("input", (_event, ctx) => { live = ctx; state.cycles = 0; cancel(); });
  pi.on("message_end", (event, ctx) => {
    // Also cover user messages injected by SDK/extensions, bypassing input hooks.
    if (event.message.role === "user") { live = ctx; state.cycles = 0; cancel(); }
  });
  pi.on("model_select", (event, ctx) => {
    live = ctx;
    if (event.previousModel && (event.previousModel.provider !== event.model.provider || event.previousModel.id !== event.model.id)) { state.cycles = 0; cancel(); }
  });
  pi.on("session_tree", (_event, ctx) => { live = ctx; restore(ctx); cancel(); });
  pi.on("agent_settled", (_event, ctx) => {
    live = ctx;
    if (ctx.mode !== "tui" || !state.enabled || ctx.hasPendingMessages()) return;
    const last = ctx.sessionManager.getBranch().filter(e => e.type === "message" && e.message.role === "assistant").at(-1);
    if (!last || last.type !== "message" || last.message.role !== "assistant") return;
    const m = last.message;
    const due = m.stopReason === "error" ? quotaReset(m.provider, m.errorMessage ?? "") : undefined;
    if (due === undefined) { if (state.pending) cancel(); return; }
    if (model(ctx) !== `${m.provider}/${m.model}` || state.pending) return;
    if (state.cycles >= MAX_CYCLES) { ctx.ui.notify("Usage resume: maximum 3 attempts reached; submit new input to reset.", "warning"); return; }
    state.pending = { session: ctx.sessionManager.getSessionId(), model: model(ctx), user: user(ctx), due };
    save(); arm();
    ctx.ui.notify(`Usage resume scheduled for ${new Date(due).toLocaleString()}. /usage-resume off cancels.`, "info");
  });
  pi.registerCommand(KEY, {
    description: "Subscription quota resume: status | off | on | now",
    handler: async (args, ctx) => {
      live = ctx;
      const action = args.trim().toLowerCase() || "status";
      if (action === "off") { state.enabled = false; cancel(); }
      else if (action === "on") { state.enabled = true; save(); arm(); }
      else if (action === "now") {
        if (ctx.mode !== "tui" || !state.enabled || !state.pending) ctx.ui.notify("No enabled interactive usage resume pending.", "warning");
        else fire();
        return;
      } else if (action !== "status") { ctx.ui.notify("Usage: /usage-resume status|off|on|now", "warning"); return; }
      ctx.ui.notify(`Usage resume ${state.enabled ? "on" : "off"} (interactive only), ${state.cycles}/${MAX_CYCLES} attempts. ${state.pending ? `Pending: ${new Date(state.pending.due).toLocaleString()}` : "Nothing pending."}`, "info");
    },
  });
}
