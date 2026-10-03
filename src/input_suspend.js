// The current generated application runs in Node or Bun. Their synchronous
// Atomics wait retains the effect continuation without an active polling loop.
// This service has not been connected or verified in a browser main thread.
function input_suspend_wait() {
  const cell = new Int32Array(new SharedArrayBuffer(4));
  for (;;) Atomics.wait(cell, 0, 0);
}
io_eff(CID(wait), input_suspend_wait);
