.t.suite "standings";

leagueId:`1124567890123456789;
users:.tf.users[leagueId; .t.fixtureJson "users.json"];
rosters:.tf.rosters[leagueId; .t.fixtureJson "rosters.json"];

standings:.view.standings[rosters;users];

.t.eq["one row per roster"; count standings; 4];

/ Standings are ordered by wins, then by points scored.
.t.eq["teams are ordered by wins then points for"; standings`rosterId; 1 4 2 3i];
.t.eq["rank follows the ordering";                 standings`rank;     1 2 3 4i];

.t.eq["the owner's team name is used";     standings[0;`teamName];  "Gridiron Gurus"];
.t.eq["the owner's display name is shown"; standings[0;`ownerName]; "GridironGuru"];
.t.eq["the owner's username is included";  standings[0;`username];  "gridironGuru"];
.t.eq["the owner's id is included so the UI can highlight it";
  standings[0;`userId]; `300000000000000001];

.t.eq["the record comes from the roster";  standings[0;`wins`losses`ties]; 2 1 0i];
.t.eq["points carry through";              standings[0;`pointsFor];        342.56];

/ A manager who never set a team name falls back to their display name.
punter:first select from standings where rosterId=3i;
.t.eq["a manager with no team name falls back to their display name";
  punter`teamName; "PunterPat"];

/ An orphan roster has no owner at all.
orphan:first select from standings where rosterId=2i;
.t.eq["an orphan roster is named after its roster id"; orphan`teamName;  "Team 2"];
.t.eq["an orphan roster has no owner name";            orphan`ownerName; "Unowned"];
.t.eq["an orphan roster has no user id";               orphan`userId;    `];

.t.eq["standings of an empty league are empty";
  count .view.standings[.schema.rosters; .schema.users];
  0];
.t.eq["standings of an empty league still have their columns";
  cols .view.standings[.schema.rosters; .schema.users];
  cols .view.standings[rosters;users]];

.t.suite "matchup pairing";

week1:.tf.matchups[leagueId; 1i; .t.fixtureJson "matchups_week1.json"];
pairs:.view.matchupPairs[week1;rosters;users];

.t.eq["matchups are grouped into head to head pairs"; count pairs; 2];
.t.eq["pairs are ordered by matchup id";              pairs[;`matchupId]; 1 2i];

first_:first pairs;
.t.eq["a pair has two teams";        count first_`teams;            2];
.t.eq["teams carry their name";      first_[`teams][0;`teamName];   "Gridiron Gurus"];
.t.eq["teams carry their score";     first_[`teams][0;`points];     118.46];
.t.eq["the higher score is the winner"; first_`winnerRosterId;      1i];
.t.true["a played matchup is marked as started"; first_`started];

/ The second matchup was decided by a commissioner override.
second:last pairs;
.t.eq["custom points decide the winner"; second`winnerRosterId; 3i];

.t.suite "matchup pairing for an unplayed week";

week5:.tf.matchups[leagueId; 5i; .t.fixtureJson "matchups_week5.json"];
future:.view.matchupPairs[week5;rosters;users];

.t.eq["a bye is its own entry alongside the real matchup"; count future; 2];
.t.false["a scoreless matchup is not marked as started";   future[0]`started];
.t.eq["a scoreless matchup has no winner";                 future[0;`winnerRosterId]; 0Ni];
.t.eq["a bye has a single team";                           count future[1]`teams;     1];

.t.eq["an empty week produces no pairs"; count .view.matchupPairs[.schema.matchups;rosters;users]; 0];

.t.suite "roster detail";

rosterPlayers:.tf.rosterPlayers[leagueId; .t.fixtureJson "rosters.json"];
players:.tf.players .t.fixtureJson "players.json";
detail:.view.rosterDetail[1i;rosters;users;rosterPlayers;players];

.t.eq["the summary names the team";     detail[`team]`teamName;  "Gridiron Gurus"];
.t.eq["the summary carries the record"; detail[`team]`wins;      2i];
.t.eq["every roster player is listed";  count detail`players;    7];

/ Starters come first, in line-up order, then the bench.
.t.eq["starters are listed first in line-up order";
  5#detail[`players]`playerId;
  `4046`4034`6794`2133`SF];
.t.eq["players are named";      detail[`players][0;`fullName];     "Patrick Mahomes"];
.t.eq["players carry position"; detail[`players][0;`position];     `QB];
.t.eq["players carry NFL team"; detail[`players][0;`team];         `KC];
.t.eq["injury status carries";  detail[`players][0;`injuryStatus]; `Questionable];

.t.throws["an unknown roster is reported clearly";
  {.view.rosterDetail[99i;rosters;users;rosterPlayers;players]};
  "roster 99"];

.t.suite "current week and the configured user";

/ The current week is the last week that has been downloaded: a refresh always
/ pulls every week up to the one the league is playing.
.t.eq["the current week is the latest downloaded week";
  .view.currentWeek raze .tf.matchups[leagueId;;] .' ((1i;.t.fixtureJson "matchups_week1.json");
                                                      (2i;.t.fixtureJson "matchups_week1.json"));
  2i];
.t.eq["a league with no matchups is on week one";
  .view.currentWeek .schema.matchups;
  1i];

.t.eq["the configured user is found by username";
  .view.configuredUserId[users;"gridironGuru"];
  `300000000000000001];
.t.eq["the username match ignores case";
  .view.configuredUserId[users;"GRIDIRONGURU"];
  `300000000000000001];
.t.eq["an unknown username matches nobody";
  .view.configuredUserId[users;"someoneElse"];
  `];
.t.eq["no configured username matches nobody";
  .view.configuredUserId[users;""];
  `];
