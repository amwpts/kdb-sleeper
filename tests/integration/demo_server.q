/ Runs the whole application against the test fixtures instead of the real
/ Sleeper API, so the user interface can be tried out without a Sleeper
/ account.  Handy for development and for reviewing the UI.
/   q tests/integration/demo_server.q -q
/ Then open http://localhost:8099

repoRoot:{[]
  parts:"/" vs $[count .z.f; string .z.f; "tests/integration/demo_server.q"];
  directory:"/" sv -3_parts;
  $[0=count directory; "."; directory]
  }[];
system "cd ",repoRoot;

system "l tests/harness.q";
.t.fixtureDir:"tests/fixtures/";
{system "l q/",x} each
  ("util.q";"config.q";"schema.q";"venues.q";"transform.q";"views.q";"storage.q";
   "http.q";"sleeper.q";"refresh.q";"api.q";"web.q");

demoDirectory:"tests/tmp/demo";
system "rm -rf \"",demoDirectory,"\"";

.app.config:`username`season`leagueId`port!("gridironGuru";"2026";"1124567890123456789";8099i);

.store.init demoDirectory;
.t.stubSleeper[];
.refresh.run[.app.config`leagueId; demoDirectory];

.web.start .app.config`port;
.log.info "Demo data only - open http://localhost:8099";
