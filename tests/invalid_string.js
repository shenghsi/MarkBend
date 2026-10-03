// Test-only unpaired surrogate. Normal Bend character creation rejects it.
function invalid_string_run() { return "\ud800"; }
io_eff(CID(Driver.invalid), invalid_string_run);
