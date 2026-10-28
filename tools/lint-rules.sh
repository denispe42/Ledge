#!/bin/zsh
# Guards the "fire and forget" rules from CLAUDE.md. Exit code 1 on any violation.
cd "${0:A:h}/.."
fail=0
check() { # description, regex, paths...
  local desc="$1" re="$2"; shift 2
  if grep -rEn --include='*.swift' --include='*.plist' --include='*.entitlements' "$re" "$@" 2>/dev/null; then
    echo "✗ $desc"; fail=1
  fi
}
check "private frameworks / runtime tricks" 'PrivateFrameworks|dlopen|dlsym|@_silgen_name|objc_getClass|NSClassFromString' Sources Resources
check "network APIs (zero-network rule)" 'URLSession|NWConnection|NWPathMonitor|CFNetwork|WKWebView|NSURLConnection|Sparkle|network\.client' Sources Resources
check "polling timers (event-driven rule)" '\bTimer\.|scheduledTimer|DispatchSource\.makeTimerSource|Timer\.publish' Sources
if grep -nE '\.package\(' Package.swift; then echo "✗ external dependencies in Package.swift"; fail=1; fi
(( fail == 0 )) && echo "lint-rules: OK"
exit $fail
