let app_pump_calls = 0;
io_eff(CID(Driver.mark), () => { app_pump_calls++; return { $: CID(Unit) }; });
io_eff(CID(Driver.finish), () => {
  if (app_pump_calls !== 10000) throw new Error("App pump skipped a retained-state continuation");
  return { $: CID(Unit) };
});
