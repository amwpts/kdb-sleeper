/ Persistence.  Each table is a single serialised file in the data directory,
/ e.g. data/users.  That is enough for a local league database and can be
/ inspected from any q session with `get \`:data/users`.
/ The live tables are held in the .db namespace: .db.league, .db.users, ...

\d .store

dataDirectory:"data";

tablePath:{[dir;name]
  hsym `$dir,"/",string name
  }

/ The in-memory table for a dataset, e.g. `users -> .db.users
tableName:{[name]
  ` sv `.db,name
  }

put:{[name;table]
  tableName[name] set table;
  }

fetch:{[name]
  value tableName name
  }

/ Several named tables as one dictionary, for functions that need a handful of
/ them at once.
fetchMany:{[names]
  names!fetch each names
  }

ensureDirectory:{[dir]
  $[.z.o in `w32`w64;
    system "if not exist \"",dir,"\" mkdir \"",dir,"\"";
    system "mkdir -p \"",dir,"\""];
  }

/ Read one table from disk, falling back to an empty table when the file is
/ missing or unreadable.  A damaged file must not stop the application from
/ starting, and must not affect the other tables.
readTable:{[dir;name]
  path:tablePath[dir;name];
  if[()~key path; :.schema name];
  loaded:@[{[p] get p}; path;
    {[name;err] .log.warn "could not read ",string[name]," (",err,"), starting with an empty table"; .schema name}[name;]];
  $[usable[name;loaded];
    loaded;
    [.log.warn "unexpected contents in ",string[name],", starting with an empty table";
     .schema name]]
  }

usable:{[name;loaded]
  $[not .Q.qt loaded; 0b;
    not (cols .schema name)~cols loaded; 0b;
    1b]
  }

writeTable:{[dir;name;table]
  tablePath[dir;name] set table;
  }

/ Load every table into memory.  Called on start-up and after a restart.
init:{[dir]
  ensureDirectory dir;
  dataDirectory::dir;
  {[dir;name] put[name; readTable[dir;name]]}[dir;] each .schema.persisted;
  }

/ Replace the given tables in memory and on disk.  Anything not named is left
/ exactly as it was, which is what keeps good data in place when only part of a
/ refresh succeeded.
commit:{[dir;changed]
  {[dir;changed;name]
    put[name; changed name];
    writeTable[dir; name; changed name];
    }[dir;changed;] each key changed;
  / the refresh log is always written so refresh times survive a restart
  writeTable[dir;`refreshLog;fetch `refreshLog];
  }

/ ---------------------------------------------------------------------------
/ Refresh times
/ ---------------------------------------------------------------------------

markRefreshed:{[datasetName;whenRefreshed]
  put[`refreshLog; (fetch `refreshLog) upsert enlist `dataset`refreshed!(datasetName;whenRefreshed)];
  }

lastRefreshed:{[datasetName]
  matches:exec refreshed from 0!fetch[`refreshLog] where dataset=datasetName;
  $[0=count matches; 0Np; first matches]
  }

/ True when a dataset has never been downloaded, or was downloaded longer ago
/ than maxAge.
isStaleAt:{[datasetName;maxAge;now]
  previous:lastRefreshed datasetName;
  $[null previous; 1b; now > previous+maxAge]
  }

isStale:{[datasetName;maxAge]
  isStaleAt[datasetName;maxAge;.z.p]
  }

\d .

/ Start with empty tables so the application always has something to serve,
/ even before anything has been loaded from disk.
{.store.put[x;.schema x]} each .schema.persisted;
