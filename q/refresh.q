/ Refresh orchestration: work out which league to load, download everything for
/ it, and commit the result in one go.
/ Nothing is written until every download and transform has succeeded, so a
/ failed refresh always leaves the previous data in place.

\d .refresh

/ The player reference list is large and changes slowly, so it is downloaded
/ about once a day.
playerCacheAge:1D00;

/ Never ask Sleeper for more weeks than a season can have.
maxWeek:18i;

/ ---------------------------------------------------------------------------
/ Which league are we looking at?
/ ---------------------------------------------------------------------------

/ Returns `leagueId`choices.  An empty leagueId together with a non-empty
/ choices table means the user has to pick one.
/ The order of preference is: the configured league, the league already stored
/ on disk, then whatever the username belongs to this season.
resolveLeague:{[cfg;storedLeague]
  if[not .cfg.needsLeagueResolution cfg;
    :`leagueId`choices!(cfg`leagueId; .schema.leagueList)];
  if[count storedLeague;
    :`leagueId`choices!(string first storedLeague`leagueId; .schema.leagueList)];
  if[0=count cfg`username;
    '"no league is configured and there is no username to look one up with"];
  profile:.sleeper.user cfg`username;
  available:.sleeper.leagues[string profile`userId; cfg`season];
  if[0=count available;
    '"no leagues found for ",(cfg`username)," in the ",(cfg`season)," season"];
  $[1=count available;
    `leagueId`choices!(string first available`leagueId; .schema.leagueList);
    `leagueId`choices!(""; available)]
  }

/ ---------------------------------------------------------------------------
/ Downloading a league
/ ---------------------------------------------------------------------------

/ Which weeks still need downloading.
/ A week that is over never changes, so it is only ever fetched once; the week
/ in progress and everything still to come are fetched again each time.
weeksToFetch:{[held;wanted;firstChangeable]
  wanted where (wanted>=firstChangeable) or not wanted in held
  }

/ Weekly actual scoring, for the weeks that have been played.
downloadWeekStats:{[season;currentWeek;held]
  weeks:weeksToFetch[held; 1i+"i"$til currentWeek & maxWeek; currentWeek];
  if[0=count weeks; :.schema.playerWeekStats];
  .log.info "Downloading week ",("," sv string weeks)," stats";
  raze .sleeper.weekStats[season;] each weeks
  }

/ Weekly projections, for the whole season: the weeks already played are needed
/ to see how players did against expectation, and the weeks to come are the
/ outlook.
downloadWeekProjections:{[season;currentWeek;held]
  weeks:weeksToFetch[held; 1i+"i"$til maxWeek; currentWeek];
  if[0=count weeks; :.schema.playerWeekProjections];
  .log.info "Downloading projections for ",string[count weeks]," week(s)";
  raze .sleeper.weekProjections[season;] each weeks
  }

/ Keep the weeks we already hold that were not downloaded again.
mergeWeeks:{[held;downloaded]
  (select from held where not week in distinct downloaded`week),downloaded
  }

/ Download everything for one league.  Each step is a separate call so that a
/ failure says which part of Sleeper was being read at the time.
download:{[leagueId;season;currentWeek;wantPlayers;heldWeekStats;heldWeekProjections]
  .log.info "Refreshing league ",leagueId;
  league:.sleeper.league leagueId;
  users:.sleeper.leagueUsers leagueId;
  .log.info "Loaded ",string[count users]," users";
  rostersJson:.sleeper.rostersPayload leagueId;
  rosters:.tf.rosters[`$leagueId; rostersJson];
  rosterPlayers:.tf.rosterPlayers[`$leagueId; rostersJson];
  .log.info "Loaded ",string[count rosters]," rosters";
  .log.info "Loaded ",string[count rosterPlayers]," roster players";
  weeks:1i+"i"$til currentWeek & maxWeek;
  matchups:raze .sleeper.matchups[leagueId;] each weeks;
  .log.info "Loaded ",string[count matchups]," matchup rows over ",string[count weeks]," week(s)";
  / Season scoring is a small download that changes every week, so unlike the
  / player reference data it comes down every time.  The same payload gives
  / both the fantasy points and every raw stat Sleeper reports.
  statsJson:.sleeper.seasonStatsPayload season;
  stats:.tf.playerStats[season;statsJson];
  statLines:.tf.statLines[season;statsJson];
  .log.info "Loaded season stats for ",string[count stats]," players (",
            string[count statLines]," stat lines)";
  schedule:.sleeper.schedule season;
  .log.info "Loaded ",string[count schedule]," schedule rows";
  weekStats:mergeWeeks[heldWeekStats; downloadWeekStats[season;currentWeek;distinct heldWeekStats`week]];
  weekProjections:mergeWeeks[heldWeekProjections;
    downloadWeekProjections[season;currentWeek;distinct heldWeekProjections`week]];
  .log.info "Holding ",string[count weekStats]," weekly stat lines and ",
            string[count weekProjections]," weekly projections";
  downloaded:`league`users`rosters`rosterPlayers`matchups`playerStats`playerStatLines`schedule`playerWeekStats`playerWeekProjections!(
    league;users;rosters;rosterPlayers;matchups;stats;statLines;schedule;weekStats;weekProjections);
  if[wantPlayers;
    players:.sleeper.players[];
    .log.info "Loaded ",string[count players]," NFL players";
    downloaded[`players]:players];
  downloaded
  }

/ Download a league and store it.  Returns a short summary for the UI.
run:{[leagueId;dir]
  state:.sleeper.state[];
  currentWeek:state`week;
  wantPlayers:.store.isStale[`players;playerCacheAge];
  downloaded:download[leagueId;state`season;currentWeek;wantPlayers;
    .store.fetch`playerWeekStats; .store.fetch`playerWeekProjections];
  now:.z.p;
  .store.markRefreshed[`league;now];
  if[wantPlayers; .store.markRefreshed[`players;now]];
  .store.commit[dir;downloaded];
  .log.info "Refresh complete";
  `leagueId`week`refreshed`playersRefreshed!(`$leagueId;currentWeek;now;wantPlayers)
  }

\d .
