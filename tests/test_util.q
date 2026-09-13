.t.suite "util - JSON field helpers";

/ A typical Sleeper object: strings, numbers, booleans, nulls and arrays.
d:.j.k "{\"name\":\"Josh Allen\",\"team\":\"BUF\",\"age\":29,\"points\":118.46,\"active\":true,\"injury_status\":null,\"fantasy_positions\":[\"QB\"],\"empty_list\":[]}";

.t.eq["str reads a string field";               .u.str[d;`name];          "Josh Allen"];
.t.eq["str of a missing key is empty";          .u.str[d;`nickname];      ""];
.t.eq["str of a JSON null is empty";            .u.str[d;`injury_status]; ""];
.t.eq["str of a number is its text form";       .u.str[d;`age];           "29"];

.t.eq["sym reads a symbol field";               .u.sym[d;`team];          `BUF];
.t.eq["sym of a missing key is null symbol";    .u.sym[d;`conference];    `];
.t.eq["sym of a JSON null is null symbol";      .u.sym[d;`injury_status]; `];

.t.eq["int reads a whole number";               .u.int[d;`age];           29i];
.t.eq["int of a missing key is null";           .u.int[d;`rank];          0Ni];
.t.eq["int of a JSON null is null";             .u.int[d;`injury_status]; 0Ni];

.t.eq["float reads a decimal";                  .u.float[d;`points];      118.46];
.t.eq["float of a missing key is null";         .u.float[d;`proj];        0n];

.t.eq["bool reads a true";                      .u.bool[d;`active];       1b];
.t.eq["bool of a missing key is false";         .u.bool[d;`rookie];       0b];
.t.eq["bool of a JSON null is false";           .u.bool[d;`injury_status];0b];

.t.eq["symList reads an array of strings";      .u.symList[d;`fantasy_positions]; enlist `QB];
.t.eq["symList of an empty array is empty";     .u.symList[d;`empty_list];        0#`];
.t.eq["symList of a missing key is empty";      .u.symList[d;`metadata];          0#`];
.t.eq["symList of a JSON null is empty";        .u.symList[d;`injury_status];     0#`];

/ Sleeper sometimes sends numbers as strings, e.g. "age":"29".
s:.j.k "{\"age\":\"29\",\"points\":\"12.5\"}";
.t.eq["int parses a numeric string";            .u.int[s;`age];    29i];
.t.eq["float parses a numeric string";          .u.float[s;`points]; 12.5];

/ Non numeric text must not blow up.
b:.j.k "{\"age\":\"unknown\"}";
.t.eq["int of unparseable text is null";        .u.int[b;`age];    0Ni];

.t.suite "util - logging";

.t.eq["log lines are timestamped and levelled";
  .log.format[2026.09.10D22:30:00.000000000;"INFO";"Refreshing league 123456"];
  "2026.09.10D22:30:00 INFO Refreshing league 123456"];

.t.eq["log level is padded so messages line up";
  .log.format[2026.09.10D22:30:00.000000000;"WARN";"slow"];
  "2026.09.10D22:30:00 WARN slow"];
