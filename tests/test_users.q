.t.suite "users transform";

leagueId:`1124567890123456789;
t:.tf.users[leagueId; .t.fixtureJson "users.json"];

.t.eq["every user is returned";        count t;            4];
.t.eq["column names match the schema"; cols t;             cols .schema.users];
.t.eq["rows fit the users schema";     .schema.users upsert t; t];

.t.eq["leagueId is stamped on every row"; distinct t`leagueId; enlist leagueId];
.t.eq["userId is a symbol";            t[0;`userId];       `300000000000000001];
.t.eq["username is text";              t[0;`username];     "gridironGuru"];
.t.eq["displayName is text";           t[0;`displayName];  "GridironGuru"];
.t.eq["teamName comes from metadata";  t[0;`teamName];     "Gridiron Gurus"];
.t.eq["avatar is text";                t[0;`avatar];       "aaaa1111"];
.t.eq["isOwner is a boolean";          t[0;`isOwner];      1b];

/ Sleeper omits metadata entirely for managers who never set a team name.
.t.eq["a user with no metadata has an empty team name"; t[1;`teamName]; ""];
.t.eq["is_owner false stays false";                     t[1;`isOwner];  0b];

/ metadata present but team_name null.
.t.eq["a null team name becomes empty text"; t[2;`teamName]; ""];
.t.eq["a null avatar becomes empty text";    t[2;`avatar];   ""];

/ is_owner missing entirely.
.t.eq["a missing is_owner is false";      t[3;`isOwner];  0b];
.t.eq["a null username becomes empty";    t[3;`username]; ""];

/ Empty and unusable responses.
.t.eq["an empty user list gives an empty table"; count .tf.users[leagueId; .j.k "[]"]; 0];
.t.eq["an empty user list still has the schema"; cols .tf.users[leagueId; .j.k "[]"]; cols .schema.users];

.t.throws["a non-list users response is rejected";
  {.tf.users[`abc; .j.k "\"not a list\""]};
  "users"];

.t.suite "user profile";

profile:.tf.userProfile .t.fixtureJson "user.json";

.t.eq["userId is a symbol";   profile`userId;      `300000000000000001];
.t.eq["username is text";     profile`username;    "gridironGuru"];
.t.eq["displayName is text";  profile`displayName; "GridironGuru"];

/ Sleeper answers an unknown username with a JSON null rather than an error.
.t.throws["an unknown username is reported clearly";
  {.tf.userProfile .j.k "null"};
  "no Sleeper user"];
