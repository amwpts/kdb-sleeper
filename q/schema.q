/ Table definitions.  Every table in the application is created empty here, so
/ the shape of the database is visible in one place and transforms have a
/ typed target to upsert into.
/ Conventions:
/   - identifiers that repeat (league, roster, user, player, team, position)
/     are symbols
/   - free text supplied by users (names, avatars) stays as strings
/   - counts are ints, points are floats, times are timestamps

\d .schema

league:([]
  leagueId:`$();
  name:();
  season:`$();
  status:`$();
  totalRosters:`int$();
  avatar:();
  previousLeagueId:`$();
  scoringFormat:`$());

/ The leagues a user belongs to, used for the league selection screen.
leagueList:([]
  leagueId:`$();
  name:();
  season:`$();
  status:`$();
  totalRosters:`int$());

users:([]
  leagueId:`$();
  userId:`$();
  username:();
  displayName:();
  teamName:();
  avatar:();
  isOwner:`boolean$());

rosters:([]
  leagueId:`$();
  rosterId:`int$();
  ownerId:`$();
  wins:`int$();
  losses:`int$();
  ties:`int$();
  pointsFor:`float$();
  pointsAgainst:`float$());

/ One row per roster/player relationship.  `slot` is the position of a starter
/ in the starting line-up, and is null for bench and reserve players.
rosterPlayers:([]
  leagueId:`$();
  rosterId:`int$();
  playerId:`$();
  starter:`boolean$();
  reserve:`boolean$();
  slot:`int$());

players:([]
  playerId:`$();
  firstName:();
  lastName:();
  fullName:();
  team:`$();
  position:`$();
  fantasyPositions:();
  status:`$();
  injuryStatus:`$();
  number:`int$();
  age:`int$());

/ Season totals from Sleeper.  All three of its scoring formats are kept, so
/ the league's own format decides which is shown without downloading again.
playerStats:([]
  playerId:`$();
  season:`$();
  games:`int$();
  pointsStd:`float$();
  pointsHalf:`float$();
  pointsPpr:`float$());

/ One row per player per week, for both what actually happened and what
/ Sleeper projected.  Together they give form, current week scoring and how a
/ player is doing against expectation.
playerWeekStats:([]
  playerId:`$();
  season:`$();
  week:`int$();
  games:`int$();
  pointsStd:`float$();
  pointsHalf:`float$();
  pointsPpr:`float$());

playerWeekProjections:([]
  playerId:`$();
  season:`$();
  week:`int$();
  pointsStd:`float$();
  pointsHalf:`float$();
  pointsPpr:`float$());

/ Every raw stat Sleeper reports, one row per player per stat.  Sleeper
/ publishes over 250 different stats and only a few dozen apply to any one
/ player, so a long table is far kinder than 250 mostly empty columns.
playerStatLines:([]
  playerId:`$();
  season:`$();
  stat:`$();
  amount:`float$());

/ The NFL schedule, one row per team per game, so a team's fixtures and byes
/ read straight off.
schedule:([]
  season:`$();
  week:`int$();
  team:`$();
  opponent:`$();
  home:`boolean$();
  gameDate:`date$();
  status:`$());

matchups:([]
  leagueId:`$();
  week:`int$();
  matchupId:`int$();
  rosterId:`int$();
  points:`float$());

/ When each dataset was last downloaded, so the player reference data can be
/ refreshed roughly once a day rather than on every refresh.
refreshLog:([dataset:`$()]
  refreshed:`timestamp$());

/ Every table that is persisted to disk.
persisted:`league`users`rosters`rosterPlayers`players`playerStats`playerWeekStats`playerWeekProjections`playerStatLines`schedule`matchups`refreshLog;

\d .
