import { execFile } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function terminalNotify(title: string, body: string): void {
  if (process.env.KITTY_WINDOW_ID) {
    process.stdout.write(`\x1b]99;i=pi:d=0;${title}\x1b\\`);
    process.stdout.write(`\x1b]99;i=pi:p=body;${body}\x1b\\`);
  } else {
    process.stdout.write(`\x1b]777;notify;${title};${body}\x07`);
  }
}

function notify(title: string, body: string): void {
  if (process.platform === "linux" && process.env.DBUS_SESSION_BUS_ADDRESS) {
    execFile("notify-send", ["--app-name=Pi", "--urgency=normal", title, body], (error) => {
      if (error) terminalNotify(title, body);
    });
    return;
  }
  terminalNotify(title, body);
}

export default function (pi: ExtensionAPI) {
  pi.on("agent_settled", () => notify("Pi", "Ready for input"));

  pi.registerCommand("notify-test", {
    description: "Send a test desktop notification",
    handler: async (_args, ctx) => {
      notify("Pi", "Test notification");
      ctx.ui.notify("Sent desktop notification test", "info");
    },
  });
}
