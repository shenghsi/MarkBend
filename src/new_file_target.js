function new_target_resolve_raw(path) {
  return { $: CID(Fail), error: io_tup(38, "New-file target resolution is unavailable on this host") };
}
io_eff(CID(resolve_raw), new_target_resolve_raw);
