import { spawn } from "node:child_process";
const [duration, command, ...args] = process.argv.slice(2);
const milliseconds = Number(duration);
if (!command || !Number.isFinite(milliseconds) || milliseconds <= 0) throw new Error("Invalid watchdog command");
const child = spawn(command, args, { stdio: "inherit" });
let expired = false;
const timer = setTimeout(() => {
  expired = true;
  process.stderr.write(`Test watchdog expired: ${command}\n`);
  child.kill("SIGKILL");
}, milliseconds);
child.on("error", error => {
  clearTimeout(timer); process.stderr.write(`${error.message}\n`); process.exitCode = 1;
});
child.on("close", (code, signal) => {
  clearTimeout(timer);
  process.exitCode = expired ? 124 : signal ? 1 : code;
});
