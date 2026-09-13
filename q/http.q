/ HTTP retrieval.  This is the only part of the application that touches the
/ network, which is what lets every transform be tested from local fixtures.
/ curl is used rather than q's own .Q.hg because the Sleeper API is HTTPS only
/ and kdb+ can only speak TLS when it finds an OpenSSL library it recognises,
/ which is not true on every machine.  curl ships with macOS and Linux and
/ reports the HTTP status code, which we need for sensible error messages.

\d .http

timeoutSeconds:30;

/ A url is pasted into a shell command, so anything that is not plain url text
/ is refused rather than escaped.
safeCharacters:.Q.a,.Q.A,.Q.n,":/._-~?&=%";

safeUrl:{[url]
  if[not all url in safeCharacters; '"unsafe characters in url: ",url];
  url
  }

/ Returns `status`body.  A status of 0 means the request never got there:
/ curl exits non-zero when it cannot connect, and q signals that as an error.
commandFor:{[url;windows]
  / cmd.exe expands paired percent signs even inside quotes.
  if[windows and "%" in url; '"percent escapes are not supported in Windows request urls"];
  $[windows;"curl.exe";"curl"]," -sS -m ",string[timeoutSeconds],
    " -w \"\\n%{http_code}\" \"",safeUrl[url],"\" 2>",$[windows;"NUL";"/dev/null"]
  }

request:{[url]
  command:commandFor[url;.z.o in `w32`w64];
  lines:@[system; command; {[err] .log.warn "curl could not complete the request (",err,")"; ()}];
  if[0=count lines; :`status`body!(0i;"")];
  `status`body!(0i^"I"$last lines; "\n" sv -1_lines)
  }

/ Turn a response into parsed JSON, or signal an error a person can act on.
/ `what` describes what was being fetched, e.g. "league 12345".
requireOk:{[response;what]
  status:response`status;
  if[status=200i; :response];
  $[status=0i;                 '"could not reach Sleeper - check your network connection";
    status=404i;               '"Sleeper could not find ",what;
    status within (500i;599i); '"Sleeper is unavailable (HTTP ",string[status],")";
    '"Sleeper returned HTTP ",string[status]," for ",what]
  }

json:{[response;what]
  requireOk[response;what];
  @[.j.k; response`body;
    {[what;err] '"malformed response from Sleeper for ",what," (",err,")"}[what;]]
  }

\d .
