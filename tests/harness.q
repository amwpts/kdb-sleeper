/ Minimal test harness.
/ Usage:
/   .t.suite "config";
/   .t.eq["description"; actual; expected];
/   .t.true["description"; boolean];
/   .t.throws["description"; {someFunction[]}; "expected error text"];

\d .t

passed:0;
failed:0;
currentSuite:"";
failures:();

suite:{[name]
  currentSuite::name;
  -1"";
  -1"  ",name;
  }

pass:{[description]
  passed+:1;
  -1"    ok   ",description;
  }

fail:{[description;detail]
  failed+:1;
  failures,:enlist currentSuite," / ",description;
  -1"    FAIL ",description;
  -1"         ",detail;
  }

/ Compare two values for exact match (type and value).
eq:{[description;actual;expected]
  $[expected~actual;
    pass description;
    fail[description;"expected: ",(.Q.s1 expected),"\n         actual:   ",.Q.s1 actual]];
  }

true:{[description;actual]
  eq[description;actual;1b];
  }

false:{[description;actual]
  eq[description;actual;0b];
  }

/ Assert that evaluating f signals an error containing `expected`.
throws:{[description;f;expected]
  result:@[{[g] (1b; g[])}; f; {[err] (0b; err)}];
  $[first result;
    fail[description;"expected error containing \"",expected,"\" but no error was signalled"];
    expected~"" ;
      pass description;
    like[last result;"*",expected,"*"];
      pass description;
    fail[description;"expected error containing \"",expected,"\"\n         actual error:  \"",(last result),"\""]];
  }

/ Load a fixture file from tests/fixtures as raw text.
fixture:{[name]
  path:hsym `$.t.fixtureDir,name;
  raw:@[read0;path;{[p;err] '"fixture not found: ",p}[string path]];
  "\n" sv raw
  }

/ Parse a fixture file as JSON.
fixtureJson:{[name]
  .j.k fixture name
  }

report:{[]
  -1"";
  -1"  ",(string passed)," passed, ",(string failed)," failed";
  if[count failures;
    -1"";
    -1"  Failures:";
    {-1"    - ",x} each failures;
    ];
  -1"";
  failed
  }

\d .
\d .t

/ Remove and recreate a directory used by a test.
resetDir:{[dir]
  system "rm -rf \"",dir,"\"";
  system "mkdir -p \"",dir,"\"";
  }

/ Replace a saved table with bytes that are not a q value.
corruptFile:{[path]
  (hsym `$path) 0: enlist "this is not a kdb+ file at all";
  }

/ Throw away the in-memory database, as if q had been restarted.
clearDatabase:{[]
  {.store.put[x;.schema x]} each .schema.persisted;
  }

\d .
\d .t

/ Swap the Sleeper transport for a stub that replays fixture text.
/ `routes` is a list of (url pattern;body) pairs, tried in order.  Every url
/ that is asked for is recorded in .t.requestedUrls.
/ Patterns are matched with `like`, which signals nyi on more than two
/ wildcards, so keep them to two.
requestedUrls:();

stubTransport:{[routes]
  requestedUrls::();
  .sleeper.transport:{[routes;url]
    .t.requestedUrls,:enlist url;
    matched:where like[url;] each routes[;0];
    if[0=count matched; '"no stub route for ",url];
    `status`body!(200i; routes[first matched;1])
    }[routes;];
  }

/ The standard set of routes, answering every endpoint from fixtures.
stubSleeper:{[]
  stubTransport (
    ("*/state/nfl";     fixture "state_nfl.json");
    ("*/players/nfl";   fixture "players.json");
    ("*/schedule/nfl/*";                 fixture "schedule.json");
    ("*/projections/nfl/regular/2026/*"; fixture "projections_week.json");
    ("*/stats/nfl/regular/2026/*";       fixture "stats_week.json");
    ("*/stats/nfl/*";   fixture "stats_season.json");
    ("*/users";         fixture "users.json");
    ("*/rosters";       fixture "rosters.json");
    ("*/matchups/*";    fixture "matchups_week1.json");
    ("*/leagues/nfl/*"; fixture "user_leagues.json");
    ("*/user/*";        fixture "user.json");
    ("*/league/*";      fixture "league.json"));
  }

asked:{[pattern]
  any requestedUrls like pattern
  }

clearRequests:{[]
  requestedUrls::();
  }

stubStatus:{[status;body]
  requestedUrls::();
  .sleeper.transport:{[status;body;url] .t.requestedUrls,:enlist url; `status`body!(status;body)}[status;body;];
  }

restoreTransport:{[]
  .sleeper.transport:.http.request;
  }

\d .
\d .t

/ Parse the JSON body of an API response.
json:{[response]
  .j.k response`body
  }

\d .
