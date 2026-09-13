/ Entry point.  From the repository root:  q q/main.q
/ Loads the application, opens the local database, downloads the league if
/ nothing has been stored yet, and starts the web server.

repoRoot:{[]
  scriptPath:$[count .z.f; string .z.f; "q/main.q"];
  parts:"/" vs scriptPath;
  directory:"/" sv -2_parts;
  $[0=count directory; "."; directory]
  }[];

/ \l cannot load a path containing spaces, so work from the repository root.
system "cd ",repoRoot;

{system "l q/",x} each
  ("util.q";"config.q";"schema.q";"venues.q";"transform.q";"views.q";"storage.q";
   "http.q";"sleeper.q";"refresh.q";"api.q";"web.q");

\d .app

describeStoredData:{[]
  if[0=count .db.league;
    .log.info "No league stored yet in ",.store.dataDirectory,"/";
    :()];
  .log.info "Loaded league ",(first .db.league`name)," from ",.store.dataDirectory,"/";
  .log.info "  ",string[count .db.rosters]," rosters, ",
            string[count .db.rosterPlayers]," roster players, ",
            string[count .db.players]," NFL players, ",
            string[count .db.matchups]," matchup rows";
  }

/ Download on start-up only when there is nothing stored.  A failure here is
/ logged and the application still starts, so the browser can show the error
/ and offer a retry.
initialRefresh:{[]
  @[{[]
      resolved:.refresh.resolveLeague[config;.db.league];
      $[0=count resolved`leagueId;
        .log.warn "You belong to ",string[count resolved`choices]," leagues this season - pick one in the browser";
        .refresh.run[resolved`leagueId;.store.dataDirectory]];
      };
    ::;
    {[err]
      .log.error "Could not download from Sleeper: ",err;
      .log.error "Starting anyway - the browser will show this and let you retry";
      }];
  }

describeConfiguration:{[]
  if[not .cfg.isConfigured config;
    .log.info "Not set up yet - the browser will ask for your Sleeper username";
    :()];
  .log.info "Configuration: username=",(config`username),
            " season=",(config`season),
            $[count config`leagueId; " league=",config`leagueId; " league=(resolve from username)"];
  }

run:{[]
  / A missing configuration file is not a problem: the browser offers a setup
  / screen and writes the file once a username has been entered.
  config::.cfg.loadOrDefault .cfg.defaultPath;
  describeConfiguration[];
  .store.init .store.dataDirectory;
  describeStoredData[];
  if[.cfg.isConfigured[config] and 0=count .db.league; initialRefresh[]];
  .web.start config`port;
  .log.info "Open http://localhost:",string[config`port]," in your browser";
  }

\d .

/ Signal a missing configuration file clearly rather than with a stack trace.
@[.app.run; ::;
  {[err]
    .log.error err;
    .log.error "See README.md for how to set up config/config.json";
    exit 1;
    }];
