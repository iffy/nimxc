switch("d", "ssl")
switch("d", "nimDebugDlOpen")
when defined(linux) and hostOS == "windows":
  switch("dynlibOverride", "ssl")
  switch("passl", "-lcrypto")
  switch("passl", "-lssl")