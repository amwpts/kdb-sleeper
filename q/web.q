/ The web server: static files from web/ and JSON from the API.
/ q answers HTTP GET through .z.ph and POST through .z.pp; both are wired to
/ respondTo, which is an ordinary function and so can be tested directly.

\d .web

root:"web";
frontPage:"index.html";

/ ---------------------------------------------------------------------------
/ Static files
/ ---------------------------------------------------------------------------

contentTypeFor:{[path]
  parts:"." vs path;
  if[2>count parts; :`txt];
  extension:`$last parts;
  $[extension in key .h.ty; extension; `txt]
  }

/ Turn a requested resource into a path inside the site directory.  Anything
/ that tries to climb out of it is refused.
resolve:{[resource]
  / (), makes sure a one character request such as "/" is a string, not a char
  wanted:(),resource;
  if[count wanted; if["/"=first wanted; wanted:1_wanted]];
  if[0=count wanted; wanted:frontPage];
  if[any ".." ~/: "/" vs wanted; '"path points outside the site: ",resource];
  root,"/",wanted
  }

/ The content type comes from the resolved file, so that a request for "/"
/ is still recognised as html.
readStatic:{[resource]
  path:resolve resource;
  handle:hsym `$path;
  if[()~key handle; '"not found"];
  `contentType`body!(contentTypeFor path; "c"$read1 handle)
  }

/ ---------------------------------------------------------------------------
/ One request
/ ---------------------------------------------------------------------------

/ `resource` is the path as q hands it over, e.g. "api/standings?week=2".
isApiCall:{[resource]
  (resource like "api/*") or resource like "/api/*"
  }

apiPath:{[resource]
  $[resource like "/*"; resource; "/",resource]
  }

respondTo:{[method;requested]
  resource:(),requested;
  if[isApiCall resource;
    answer:.api.route[method; apiPath resource];
    :`status`contentType`body!(answer`status; `json; answer`body)];
  if[not method~"GET";
    :`status`contentType`body!(405i;`txt;method," is not supported")];
  outcome:@[{[resource] (1b; readStatic resource)}; resource; {[err] (0b;err)}];
  if[first outcome;
    file:last outcome;
    :`status`contentType`body!(200i; file`contentType; file`body)];
  reason:last outcome;
  $[reason like "*outside*";
    `status`contentType`body!(403i;`txt;"forbidden");
    `status`contentType`body!(404i;`txt;"not found: ",resource)]
  }

/ ---------------------------------------------------------------------------
/ Wiring into q's HTTP hooks
/ ---------------------------------------------------------------------------

statusText:{[status]
  $[status=200i; "200 OK";
    status=400i; "400 Bad Request";
    status=403i; "403 Forbidden";
    status=404i; "404 Not Found";
    status=405i; "405 Method Not Allowed";
    status=502i; "502 Bad Gateway";
    (string status)," Error"]
  }

/ Every page, script and stylesheet is read from disk on each request, so a
/ browser holding on to an old copy is only ever confusing.
noCache:"Cache-Control: no-cache";

asHttp:{[answer]
  lines:"\r\n" vs .h.hn[statusText answer`status; answer`contentType; answer`body];
  "\r\n" sv (first lines;noCache),1_lines
  }

/ q calls .z.ph with the requested resource, and .z.pp with the resource, a
/ space, and the request body.  Only the resource is routed.
pathOf:{[request]
  text:(),$[10h=type request; request; first request];
  boundary:text?" ";
  boundary#text
  }

serve:{[method;request]
  resource:pathOf request;
  answer:@[respondTo[method;]; resource; {[err] `status`contentType`body!(500i;`txt;err)}];
  asHttp answer
  }

/ Bound to localhost only: this is a personal application that reads your
/ league and writes your configuration file, so it should not be reachable
/ from the rest of the network.
start:{[port]
  system "p localhost:",string port;
  .log.info "Serving on http://localhost:",string port;
  }

\d .

.z.ph:{[request] .web.serve["GET";request]}
.z.pp:{[request] .web.serve["POST";request]}
