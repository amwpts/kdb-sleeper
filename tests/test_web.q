.t.suite "web - content types";

.t.eq["html files are served as html"; .web.contentTypeFor "index.html"; `html];
.t.eq["css files are served as css";   .web.contentTypeFor "css/style.css"; `css];
.t.eq["js files are served as js";     .web.contentTypeFor "js/app.js";     `js];
.t.eq["json files are served as json"; .web.contentTypeFor "data.json";     `json];
.t.eq["an unknown extension is served as plain text";
  .web.contentTypeFor "notes.qqq"; `txt];
.t.eq["a file with no extension is served as plain text";
  .web.contentTypeFor "LICENCE"; `txt];

.t.suite "web - resolving paths";

.t.eq["an empty path is the front page";     .web.resolve "";           "web/index.html"];
.t.eq["a bare slash is the front page";      .web.resolve "/";          "web/index.html"];
.t.eq["a file path is served from web/";     .web.resolve "css/style.css"; "web/css/style.css"];
.t.eq["a leading slash is ignored";          .web.resolve "/js/app.js";  "web/js/app.js"];

/ Nothing outside the web directory may ever be served.
.t.throws["a path that climbs out of web/ is refused";
  {.web.resolve "../config/config.json"};
  "outside"];
.t.throws["a path that climbs out half way through is refused";
  {.web.resolve "css/../../q/config.q"};
  "outside"];

.t.suite "web - serving static files";

/ Point the server at a small fixture site for these tests.
.web.root:"tests/fixtures/static";

page:.web.respondTo["GET";""];
.t.eq["the front page is served";        page`status;      200i];
.t.eq["the front page is html";          page`contentType; `html];
.t.true["the front page has content";    0<count page`body];

style:.web.respondTo["GET";"css/demo.css"];
.t.eq["a stylesheet is served";          style`status;      200i];
.t.eq["a stylesheet has the css type";   style`contentType; `css];

missing:.web.respondTo["GET";"nowhere.html"];
.t.eq["a file that does not exist is a 404"; missing`status; 404i];
.t.true["a missing file explains itself";    0<count missing`body];

escape:.web.respondTo["GET";"../q/config.q"];
.t.eq["a path outside the site is refused"; escape`status; 403i];

.web.root:"web";

.t.suite "web - routing to the API";

apiCall:.web.respondTo["GET";"api/league"];
.t.eq["api calls are answered as json";  apiCall`contentType; `json];
.t.eq["api calls carry the api status";  apiCall`status;      200i];

.t.eq["a leading slash on an api path still routes";
  (.web.respondTo["GET";"/api/standings"])`contentType;
  `json];

.t.eq["an unknown api path is a 404";
  (.web.respondTo["GET";"api/nope"])`status;
  404i];

.t.eq["a post to an api path is routed as a post";
  (.web.respondTo["POST";"api/nope"])`status;
  404i];

.t.suite "web - the request q hands over";

/ q gives .z.ph the resource, and .z.pp the resource followed by a space and
/ the request body.  Only the resource is ever routed.
.t.eq["a GET resource is used as it is";
  .web.pathOf ("api/standings?week=2"; ()!());
  "api/standings?week=2"];
.t.eq["a POST body is not part of the path";
  .web.pathOf ("api/refresh {\"leagueId\":\"7\"}"; ()!());
  "api/refresh"];
.t.eq["a POST with an empty body has no trailing space";
  .web.pathOf ("api/refresh "; ()!());
  "api/refresh"];
.t.eq["a plain string request is accepted too";
  .web.pathOf "api/league";
  "api/league"];

.t.suite "web - the HTTP response";

.web.root:"tests/fixtures/static";
response:.web.asHttp .web.respondTo["GET";""];

.t.true["the response starts with the status line";
  response like "HTTP/1.1 200 OK*"];
.t.true["the response says what it is sending";
  response like "*Content-Type: text/html*"];
.t.true["the response carries the page itself";
  response like "*fixture page*"];

/ Every file is read from disk on each request, so a browser holding on to an
/ old copy of a script is only ever confusing.
.t.true["the browser is told not to cache the response";
  response like "*Cache-Control: no-cache*"];
.t.true["json replies say the same";
  (.web.asHttp .web.respondTo["GET";"api/league"]) like "*Cache-Control: no-cache*"];

.web.root:"web";
