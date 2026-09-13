.t.suite "players transform";

t:.tf.players .t.fixtureJson "players.json";
byId:{[players;id] first select from players where playerId=id}[t;];

.t.eq["every player is returned";      count t;                  14];
.t.eq["column names match the schema"; cols t;                   cols .schema.players];
.t.eq["rows fit the players schema";   .schema.players upsert t; t];

mccaffrey:byId[`4034];
.t.eq["playerId is a symbol";          first exec playerId from t where playerId=`4034; `4034];
.t.eq["firstName is text";             mccaffrey`firstName;      "Christian"];
.t.eq["lastName is text";              mccaffrey`lastName;       "McCaffrey"];
.t.eq["fullName is text";              mccaffrey`fullName;       "Christian McCaffrey"];
.t.eq["team is a symbol";              mccaffrey`team;           `SF];
.t.eq["position is a symbol";          mccaffrey`position;       `RB];
.t.eq["fantasyPositions is a symbol list"; mccaffrey`fantasyPositions; enlist `RB];
.t.eq["status is a symbol";            mccaffrey`status;         `Active];
.t.eq["a null injury status is the null symbol"; mccaffrey`injuryStatus; `];
.t.eq["number is an int";              mccaffrey`number;         23i];
.t.eq["age is an int";                 mccaffrey`age;            30i];

.t.eq["an injury status is kept";      byId[`4046]`injuryStatus; `Questionable];
.t.eq["multiple fantasy positions are kept"; byId[`6794]`fantasyPositions; `WR`TE];
.t.eq["a null fantasy position list is empty"; byId[`1339]`fantasyPositions; 0#`];

/ Team defences are players too, but Sleeper gives them no full_name.
defence:byId[`SF];
.t.eq["a defence keeps its team code as the player id"; defence`playerId; `SF];
.t.eq["a defence is given the DEF position";            defence`position; `DEF];
.t.eq["a defence full name is built from its parts";    defence`fullName; "San Francisco 49ers"];
.t.eq["a missing number is a null int";                 defence`number;   0Ni];
.t.eq["a missing age is a null int";                    defence`age;      0Ni];

/ Sleeper includes a placeholder entry with no name at all.
placeholder:byId[`$enlist "0"];
.t.eq["a nameless player gets an empty full name"; placeholder`fullName; ""];
.t.eq["a null team is the null symbol";            placeholder`team;     `];

.t.eq["an empty players response gives an empty table"; count .tf.players .j.k "{}"; 0];
.t.eq["an empty players response still has the schema"; cols .tf.players .j.k "{}"; cols .schema.players];

.t.throws["a players response that is not an object is rejected";
  {.tf.players .j.k "[]"};
  "players"];

.t.suite "player lookup";

/ Joining roster player ids to player names is the most common lookup in the UI.
named:.tf.withPlayerNames[.tf.rosterPlayers[`L; .t.fixtureJson "rosters.json"]; t];

.t.eq["known players get their full name";
  first exec fullName from named where playerId=`4034;
  "Christian McCaffrey"];
.t.eq["known players get their position";
  first exec position from named where playerId=`4034;
  `RB];
.t.eq["an unknown player id is not dropped";
  count select from named where playerId=`9999;
  1];
.t.eq["an unknown player id falls back to its id as a name";
  first exec fullName from named where playerId=`9999;
  "9999"];
.t.eq["an unknown player has no position";
  first exec position from named where playerId=`9999;
  `];
