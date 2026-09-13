.t.suite "config";

valid:.cfg.parseText .t.fixture "config_valid.json";

.t.eq["username is read as a string";      valid`username;  "gridironGuru"];
.t.eq["season is read as a string";        valid`season;    "2026"];
.t.eq["leagueId is read as a string";      valid`leagueId;  "1124567890123456789"];
.t.eq["port is read as an int";            valid`port;      8080i];

/ Optional fields fall back to sensible defaults.
minimal:.cfg.parseText .t.fixture "config_minimal.json";
.t.eq["missing leagueId defaults to empty"; minimal`leagueId; ""];
.t.eq["missing port defaults to 8080";      minimal`port;     8080i];
.t.eq["missing season defaults to current NFL season"; minimal`season; .cfg.defaultSeason[]];

/ An empty leagueId is legal - it means "resolve the league from the username".
noLeague:.cfg.parseText .t.fixture "config_no_league.json";
.t.eq["empty leagueId is allowed";          noLeague`leagueId; ""];
.t.true["league needs resolving when leagueId is empty"; .cfg.needsLeagueResolution noLeague];
.t.false["league does not need resolving when leagueId is set"; .cfg.needsLeagueResolution valid];

/ Validation errors.
/ A configuration with no username and no league is not an error any more:
/ it means "not set up yet", and the browser offers a setup screen.
blank:.cfg.parseText .t.fixture "config_empty.json";
.t.false["a config with neither username nor leagueId is not configured";
  .cfg.isConfigured blank];
.t.true["a config with a username is configured";     .cfg.isConfigured valid];
.t.true["a config with only a leagueId is configured";
  .cfg.isConfigured `username`season`leagueId`port!("";"2026";"123";8080i)];

.t.throws["malformed JSON gives a readable error";
  {.cfg.parseText .t.fixture "config_malformed.json"};
  "not valid JSON"];

.t.throws["a missing config file gives a readable error";
  {.cfg.loadFile "config/does_not_exist.json"};
  "no configuration file"];

/ Loading from disk goes through the same parsing path.
.t.eq["load reads and parses a file";
  (.cfg.loadFile "tests/fixtures/config_valid.json")`username;
  "gridironGuru"];

/ The default season is a four digit year.
.t.eq["default season looks like a year"; count .cfg.defaultSeason[]; 4];

.t.suite "config - writing it back";

/ The browser writes the configuration file, so it has to stay in the same
/ readable shape somebody would type by hand.
written:.cfg.toJson `username`season`leagueId`port!("gridironGuru";"2026";"112233";8080i);

.t.eq["the written config is readable JSON";
  written;
  "{\n  \"username\": \"gridironGuru\",\n  \"season\": \"2026\",\n  \"leagueId\": \"112233\",\n  \"port\": 8080\n}\n"];

.t.eq["what is written can be read back";
  .cfg.parseText written;
  `username`season`leagueId`port!("gridironGuru";"2026";"112233";8080i)];

.t.eq["a config with no league can be written and read back";
  (.cfg.parseText .cfg.toJson `username`season`leagueId`port!("bob";"2026";"";8080i))`leagueId;
  ""];

/ Saving to disk.
.t.resetDir "tests/tmp/config";
path:"tests/tmp/config/config.json";
saved:`username`season`leagueId`port!("gridironGuru";"2026";"112233";8099i);
.cfg.writeFile[path;saved];

.t.eq["a saved config can be loaded again"; .cfg.loadFile path; saved];

/ Saving again replaces the file rather than appending to it.
.cfg.writeFile[path;`username`season`leagueId`port!("someoneElse";"2025";"";8099i)];
.t.eq["saving again replaces the previous file"; (.cfg.loadFile path)`username; "someoneElse"];
.t.eq["the replaced file has no leftovers"; (.cfg.loadFile path)`leagueId; ""];

.t.suite "config - starting without a file";

.t.eq["a missing config file gives an empty configuration";
  .cfg.loadOrDefault "tests/tmp/config/not-here.json";
  .cfg.empty[]];
.t.false["an empty configuration is not configured"; .cfg.isConfigured .cfg.empty[]];
.t.eq["an empty configuration still has a port";     (.cfg.empty[])`port;   8080i];
.t.eq["an empty configuration still has a season";   (.cfg.empty[])`season; .cfg.defaultSeason[]];
.t.eq["an existing file is still read normally";
  (.cfg.loadOrDefault path)`username;
  "someoneElse"];

.t.resetDir "tests/tmp/config";
