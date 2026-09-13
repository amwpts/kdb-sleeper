/ Pure transformations from parsed Sleeper JSON into q tables.
/ Nothing in this file performs IO, so every function can be tested against the
/ fixtures in tests/fixtures.

\d .tf

/ Sleeper array endpoints return a JSON list.  .j.k gives a table when every
/ object in the array has the same keys and a list of dictionaries when they
/ differ; both iterate row by row, so both are accepted here.
asList:{[payload;what]
  $[payload~(::);          ();
    0h=type payload;       payload;
    98h=type payload;      payload;
    99h=type payload;      enlist payload;
    '"expected a list of ",what," from Sleeper"]
  }

requireObject:{[payload;what]
  if[not 99h=type payload; '"expected a ",what," object from Sleeper"];
  payload
  }

/ ---------------------------------------------------------------------------
/ League
/ ---------------------------------------------------------------------------

/ Sleeper publishes fantasy points already worked out three ways: standard,
/ half point per reception and full point per reception.  The league's own
/ scoring settings say which of the three to show.
scoringFormat:{[scoring]
  if[not 99h=type scoring; :`std];
  perReception:0f^.u.float[scoring;`rec];
  $[perReception>0.5; `ppr;
    perReception>0f;   `half;
    `std]
  }

leagueRow:{[obj]
  `leagueId`name`season`status`totalRosters`avatar`previousLeagueId`scoringFormat!(
    .u.sym[obj;`league_id];
    .u.str[obj;`name];
    .u.sym[obj;`season];
    .u.sym[obj;`status];
    .u.int[obj;`total_rosters];
    .u.str[obj;`avatar];
    .u.sym[obj;`previous_league_id];
    scoringFormat .u.field[obj;`scoring_settings])
  }

league:{[obj]
  requireObject[obj;"league"];
  .schema.league upsert enlist leagueRow obj
  }

/ The leagues a user belongs to in a season.
leagueList:{[arr]
  leagues:asList[arr;"leagues"];
  if[0=count leagues; :.schema.leagueList];
  rows:leagueRow each leagues;
  .schema.leagueList upsert (cols .schema.leagueList)#/:rows
  }

\d .
\d .tf

/ ---------------------------------------------------------------------------
/ Users
/ ---------------------------------------------------------------------------

/ A manager's team name lives in metadata, which Sleeper omits when the manager
/ has never set one.
teamNameOf:{[obj]
  metadata:.u.field[obj;`metadata];
  $[99h=type metadata; .u.str[metadata;`team_name]; ""]
  }

userRow:{[leagueId;obj]
  `leagueId`userId`username`displayName`teamName`avatar`isOwner!(
    leagueId;
    .u.sym[obj;`user_id];
    .u.str[obj;`username];
    .u.str[obj;`display_name];
    teamNameOf obj;
    .u.str[obj;`avatar];
    .u.bool[obj;`is_owner])
  }

users:{[leagueId;arr]
  entries:asList[arr;"users"];
  if[0=count entries; :.schema.users];
  .schema.users upsert userRow[leagueId;] each entries
  }

\d .
\d .tf

/ ---------------------------------------------------------------------------
/ Rosters
/ ---------------------------------------------------------------------------

/ Sleeper reports points as a whole number plus a separate hundredths field,
/ e.g. fpts 342 with fpts_decimal 56 means 342.56.  Combining them in whole
/ hundredths before dividing keeps the result exact.
pointsFrom:{[settings;wholeField;decimalField]
  whole:0f^.u.float[settings;wholeField];
  hundredths:.u.int[settings;decimalField];
  $[null hundredths; whole; ((100*whole)+hundredths)%100]
  }

settingsOf:{[obj]
  settings:.u.field[obj;`settings];
  $[99h=type settings; settings; ()!()]
  }

rosterRow:{[leagueId;obj]
  settings:settingsOf obj;
  `leagueId`rosterId`ownerId`wins`losses`ties`pointsFor`pointsAgainst!(
    leagueId;
    .u.int[obj;`roster_id];
    .u.sym[obj;`owner_id];
    0i^.u.int[settings;`wins];
    0i^.u.int[settings;`losses];
    0i^.u.int[settings;`ties];
    pointsFrom[settings;`fpts;`fpts_decimal];
    pointsFrom[settings;`fpts_against;`fpts_against_decimal])
  }

rosters:{[leagueId;arr]
  entries:asList[arr;"rosters"];
  if[0=count entries; :.schema.rosters];
  .schema.rosters upsert rosterRow[leagueId;] each entries
  }

/ ---------------------------------------------------------------------------
/ Roster / player relationships
/ ---------------------------------------------------------------------------

/ An unfilled starting slot is reported as the player id "0".
emptySlot:enlist "0";

toSymbols:{[strings]
  wanted:strings where not (strings~\:emptySlot) or 0=count each strings;
  $[0=count wanted; 0#`; `$wanted]
  }

rosterPlayerRows:{[leagueId;obj]
  rosterId:.u.int[obj;`roster_id];
  lineUp:.u.strList[obj;`starters];
  / Keep the position of each starter in the line-up before dropping the
  / unfilled slots, so slot numbers still line up with the league's positions.
  filled:where not (lineUp~\:emptySlot) or 0=count each lineUp;
  starterIds:$[0=count filled; 0#`; `$lineUp filled];
  starterSlots:"i"$filled;
  reserveIds:toSymbols .u.strList[obj;`reserve];
  playerIds:distinct (toSymbols .u.strList[obj;`players]),starterIds,reserveIds;
  if[0=count playerIds; :.schema.rosterPlayers];
  ([] leagueId:count[playerIds]#leagueId;
      rosterId:count[playerIds]#rosterId;
      playerId:playerIds;
      starter:playerIds in starterIds;
      reserve:playerIds in reserveIds;
      slot:(starterSlots,0Ni) starterIds?playerIds)
  }

rosterPlayers:{[leagueId;arr]
  entries:asList[arr;"rosters"];
  if[0=count entries; :.schema.rosterPlayers];
  .schema.rosterPlayers upsert raze rosterPlayerRows[leagueId;] each entries
  }

\d .
\d .tf

/ ---------------------------------------------------------------------------
/ Players
/ ---------------------------------------------------------------------------

/ Team defences have no full_name, so build one from the parts we do have.
fullNameOf:{[obj]
  explicit:.u.str[obj;`full_name];
  if[count explicit; :explicit];
  parts:(.u.str[obj;`first_name];.u.str[obj;`last_name]);
  parts:parts where 0<count each parts;
  $[0=count parts; ""; " " sv parts]
  }

playerRow:{[id;obj]
  fromBody:.u.sym[obj;`player_id];
  `playerId`firstName`lastName`fullName`team`position`fantasyPositions`status`injuryStatus`number`age!(
    $[null fromBody; id; fromBody];
    .u.str[obj;`first_name];
    .u.str[obj;`last_name];
    fullNameOf obj;
    .u.sym[obj;`team];
    .u.sym[obj;`position];
    .u.symList[obj;`fantasy_positions];
    .u.sym[obj;`status];
    .u.sym[obj;`injury_status];
    .u.int[obj;`number];
    .u.int[obj;`age])
  }

/ /players/nfl is one large object keyed by player id.
players:{[obj]
  requireObject[obj;"players"];
  if[0=count obj; :.schema.players];
  ids:key obj;
  entries:obj ids;
  usable:where 99h=type each entries;
  if[0=count usable; :.schema.players];
  .schema.players upsert playerRow'[ids usable; entries usable]
  }

/ A single blank player, used so that unknown player ids still produce a row.
blankPlayer:{[]
  .schema.players upsert enlist
    `playerId`firstName`lastName`fullName`team`position`fantasyPositions`status`injuryStatus`number`age!
    (`;"";"";"";`;`;0#`;`;`;0Ni;0Ni)
  }

/ Attach player reference data to any table with a playerId column.  Unknown
/ ids are kept and fall back to showing the raw id, which is what the UI needs
/ when the player cache is older than the roster.
withPlayerNames:{[relationships;playersTable]
  lookup:playersTable,blankPlayer[];
  positions:(playersTable`playerId)?relationships`playerId;
  matched:((cols[lookup] except `playerId)#lookup) positions;
  joined:relationships,'matched;
  update fullName:string playerId from joined where 0=count each fullName
  }

\d .
\d .tf

/ ---------------------------------------------------------------------------
/ Matchups
/ ---------------------------------------------------------------------------

/ A commissioner can override a score, in which case custom_points is the score
/ that counts.
scoreOf:{[obj]
  custom:.u.float[obj;`custom_points];
  $[null custom; 0f^.u.float[obj;`points]; custom]
  }

matchupRow:{[leagueId;week;obj]
  `leagueId`week`matchupId`rosterId`points!(
    leagueId;
    week;
    .u.int[obj;`matchup_id];
    .u.int[obj;`roster_id];
    scoreOf obj)
  }

matchups:{[leagueId;week;arr]
  entries:asList[arr;"matchups"];
  if[0=count entries; :.schema.matchups];
  .schema.matchups upsert matchupRow[leagueId;week;] each entries
  }

/ ---------------------------------------------------------------------------
/ NFL state
/ ---------------------------------------------------------------------------

/ /state/nfl tells us which week the league is in.  Week 0 during the preseason
/ is not a week anyone can look at, so it is reported as week 1.
state:{[obj]
  requireObject[obj;"state"];
  week:.u.int[obj;`week];
  displayWeek:.u.int[obj;`display_week];
  `week`displayWeek`season`seasonType!(
    1i|1i^week;
    1i|1i^displayWeek;
    .u.str[obj;`season];
    .u.str[obj;`season_type])
  }

\d .
\d .tf

/ ---------------------------------------------------------------------------
/ Season stats
/ ---------------------------------------------------------------------------

statsRow:{[season;id;obj]
  `playerId`season`games`pointsStd`pointsHalf`pointsPpr!(
    id;
    `$season;
    0i^.u.int[obj;`gp];
    0f^.u.float[obj;`pts_std];
    0f^.u.float[obj;`pts_half_ppr];
    0f^.u.float[obj;`pts_ppr])
  }

/ Sleeper publishes whole team offensive totals alongside the players, under
/ ids like TEAM_SF.  A team's combined scoring is not a player, so it is left
/ out.  Team defences keep the plain team id (SF) and are players.
teamTotal:{[id]
  (string id) like "TEAM_*"
  }

/ /stats/nfl/regular/<season> is one object keyed by player id.  Players
/ Sleeper has nothing at all for come back as null and are skipped.
playerStats:{[season;obj]
  requireObject[obj;"stats"];
  if[0=count obj; :.schema.playerStats];
  ids:key obj;
  entries:obj ids;
  usable:where (99h=type each entries) and not teamTotal each ids;
  if[0=count usable; :.schema.playerStats];
  .schema.playerStats upsert statsRow[season]'[ids usable; entries usable]
  }

/ ---------------------------------------------------------------------------
/ Raw stat lines
/ ---------------------------------------------------------------------------

/ Fantasy points have their own table, so they are not repeated as stat lines.
pointsFields:`pts_std`pts_half_ppr`pts_ppr;

statLinesFor:{[season;id;obj]
  names:(key obj) except pointsFields;
  amounts:.u.float[obj;] each names;
  keep:where not null amounts;
  if[0=count keep; :.schema.playerStatLines];
  ([] playerId:count[keep]#id;
      season:count[keep]#`$season;
      stat:names keep;
      amount:amounts keep)
  }

statLines:{[season;obj]
  requireObject[obj;"stats"];
  if[0=count obj; :.schema.playerStatLines];
  ids:key obj;
  entries:obj ids;
  usable:where (99h=type each entries) and not teamTotal each ids;
  if[0=count usable; :.schema.playerStatLines];
  .schema.playerStatLines upsert raze statLinesFor[season]'[ids usable; entries usable]
  }

/ ---------------------------------------------------------------------------
/ The NFL schedule
/ ---------------------------------------------------------------------------

/ Each game becomes two rows, one from each team's point of view.  A game that
/ does not yet know both teams is skipped.
scheduleRows:{[season;game]
  home:.u.sym[game;`home];
  away:.u.sym[game;`away];
  if[any null (home;away); :.schema.schedule];
  week:.u.int[game;`week];
  played:"D"$.u.str[game;`date];
  ([] season:2#`$season;
      week:2#week;
      team:(home;away);
      opponent:(away;home);
      home:10b;
      gameDate:2#played;
      status:2#.u.sym[game;`status])
  }

schedule:{[season;arr]
  games:asList[arr;"schedule"];
  if[0=count games; :.schema.schedule];
  .schema.schedule upsert raze scheduleRows[season;] each games
  }

/ ---------------------------------------------------------------------------
/ Weekly stats and projections
/ ---------------------------------------------------------------------------

/ Both the weekly stats and the weekly projections arrive in the same shape as
/ the season totals, so one parser serves all of them.  `extra` says which
/ fields to add on top of the points.
/ True when an entry carries any fantasy points at all.
hasPoints:{[obj]
  not all null (.u.float[obj;`pts_std];.u.float[obj;`pts_half_ppr];.u.float[obj;`pts_ppr])
  }

/ A weekly stats entry is worth keeping when the player was recorded as
/ playing, even if they scored nothing.  A projection is only worth keeping
/ when there is actually a projection: Sleeper sends an entry for thousands of
/ players it does not project, and a bye week arrives the same way.
worthKeeping:{[obj;withGames]
  $[withGames; (not null .u.int[obj;`gp]) or hasPoints obj; hasPoints obj]
  }

weekRows:{[target;season;week;obj;withGames]
  requireObject[obj;"stats"];
  if[0=count obj; :target];
  ids:key obj;
  entries:obj ids;
  usable:where (99h=type each entries) and not teamTotal each ids;
  if[0=count usable; :target];
  usable:usable where worthKeeping[;withGames] each entries usable;
  if[0=count usable; :target];
  wanted:ids usable;
  bodies:entries usable;
  base:flip `playerId`season`week`pointsStd`pointsHalf`pointsPpr!(
    wanted;
    count[wanted]#`$season;
    count[wanted]#week;
    0f^.u.float[;`pts_std] each bodies;
    0f^.u.float[;`pts_half_ppr] each bodies;
    0f^.u.float[;`pts_ppr] each bodies);
  if[withGames;
    base:base,'([] games:0i^.u.int[;`gp] each bodies)];
  target upsert (cols target)#base
  }

weekStats:{[season;week;obj]
  weekRows[.schema.playerWeekStats;season;week;obj;1b]
  }

weekProjections:{[season;week;obj]
  weekRows[.schema.playerWeekProjections;season;week;obj;0b]
  }

/ ---------------------------------------------------------------------------
/ User profile (used to turn a username into a user id)
/ ---------------------------------------------------------------------------

/ Sleeper answers /user/<unknown> with a JSON null rather than an error status.
userProfile:{[obj]
  if[not 99h=type obj; '"there is no Sleeper user with that username"];
  `userId`username`displayName`avatar!(
    .u.sym[obj;`user_id];
    .u.str[obj;`username];
    .u.str[obj;`display_name];
    .u.str[obj;`avatar])
  }

\d .
