switch("d", "ssl")
when defined(linux):
  switch("dynlibOverride", "ssl")
  switch("passl", "-lcrypto")
  switch("passl", "-lssl")