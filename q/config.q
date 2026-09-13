/ Application configuration.
/ Read from config/config.json.  Parsing is kept separate from file reading so
/ it can be tested against fixtures.

\d .cfg

defaultPath:"config/config.json";
defaultPort:8080i;

/ The NFL league year rolls over in March, so before then the current fantasy
/ season is still the previous calendar year.
defaultSeason:{[]
  today:.z.D;
  monthNumber:1+(`mm$today) mod 12;
  string $[3<=monthNumber; `year$today; -1+`year$today]
  }

/ Parse configuration text, applying defaults and validating the result.
parseText:{[text]
  raw:@[.j.k; text; {[err] '"config is not valid JSON (",err,")"}];
  if[not 99h=type raw; '"config must be a JSON object"];
  cfg:`username`season`leagueId`port!(
    .u.str[raw;`username];
    .u.str[raw;`season];
    .u.str[raw;`leagueId];
    .u.int[raw;`port]);
  if[0=count cfg`season; cfg[`season]:defaultSeason[]];
  if[null cfg`port;      cfg[`port]:defaultPort];
  validate cfg
  }

/ A configuration with neither a username nor a league is legal: it simply
/ means the application has not been set up yet, and the browser offers a
/ setup screen.
isConfigured:{[cfg]
  0<count[cfg`username]+count cfg`leagueId
  }

validate:{[cfg]
  if[4<>count cfg`season;
    '"config season must be a four digit year, got \"",(cfg`season),"\""];
  cfg
  }

/ True when we have to look the league up from the username.
needsLeagueResolution:{[cfg]
  0=count cfg`leagueId
  }

loadFile:{[path]
  file:hsym `$path;
  if[()~key file;
    '"no configuration file at ",path," (copy config/config.example.json to config/config.json)"];
  parseText "\n" sv read0 file
  }

loadDefault:{[]
  loadFile defaultPath
  }

/ ---------------------------------------------------------------------------
/ Starting without a configuration file, and writing one from the browser
/ ---------------------------------------------------------------------------

empty:{[]
  `username`season`leagueId`port!("";defaultSeason[];"";defaultPort)
  }

loadOrDefault:{[path]
  $[()~key hsym `$path; empty[]; loadFile path]
  }

/ Written in the same shape somebody would type by hand, so the file stays
/ comfortable to edit afterwards.
quoted:{[text]
  "\"",text,"\""
  }

toJson:{[cfg]
  lines:(
    "  ",(quoted "username"),": ",quoted cfg`username;
    "  ",(quoted "season"),": ",  quoted cfg`season;
    "  ",(quoted "leagueId"),": ",quoted cfg`leagueId;
    "  ",(quoted "port"),": ",    string cfg`port);
  "{\n",(",\n" sv lines),"\n}\n"
  }

writeFile:{[path;cfg]
  (hsym `$path) 0: enlist -1_toJson cfg;
  cfg
  }

\d .
