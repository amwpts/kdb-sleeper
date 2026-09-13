/ Test runner.  From anywhere:  q <repo>/tests/runTests.q -q
/ Runs every tests/test_*.q file and exits non-zero if any test failed.

/ Change to the repository root so every later path can be relative.
/ (\l cannot load paths containing spaces, cd can.)
repoRoot:{[]
  scriptPath:$[count .z.f; string .z.f; "tests/runTests.q"];
  parts:"/" vs scriptPath;
  directory:"/" sv -2_parts;
  $[0=count directory; "."; directory]
  }[];

system "cd ",repoRoot;

system "l tests/harness.q";
.t.fixtureDir:"tests/fixtures/";

/ Application source, loaded once in dependency order.
sourceFiles:("util.q";"config.q";"schema.q";"venues.q";"transform.q";"views.q";"storage.q";
             "http.q";"sleeper.q";"refresh.q";"api.q";"web.q");
missing:sourceFiles where not (`$sourceFiles) in key `:q;
if[count missing; '"missing source file(s): ","," sv missing];
{system "l q/",x} each sourceFiles;

/ Safety net: no test may ever write to the real configuration file.
system "mkdir -p tests/tmp";
.cfg.defaultPath:"tests/tmp/test-config.json";

testFiles:asc key `:tests;
testFiles:testFiles where testFiles like "test_*.q";

-1"Running ",(string count testFiles)," test file(s)";

/ Each file is trapped so that one broken file does not hide the other results.
runFile:{[fileName]
  @[system; "l tests/",string fileName;
    {[f;err] .t.fail["test file ",(string f)," did not finish";err]}[fileName]];
  }

runFile each testFiles;

exit .t.report[];
