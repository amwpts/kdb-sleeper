/ Shared helpers: safe access to parsed Sleeper JSON, and simple logging.
/ .j.k gives us dictionaries where numbers are floats, JSON null is 0n and a
/ missing key is simply absent.  Sleeper is inconsistent about all three, so
/ every transform reads fields through these helpers rather than indexing
/ dictionaries directly.

\d .u

/ Value of a field, or (::) when the key is not present at all.
/ (Named `field` rather than `get` because `get` is a reserved q keyword.)
field:{[d;name]
  $[not 99h=type d; ::;
    name in key d;   d name;
    ::]
  }

/ True when a value carries no information: absent, JSON null, or empty text.
isEmpty:{[v]
  $[v~(::);            1b;
    10h=type v;        0=count v;
    0h=type v;         0=count v;
    -9h=type v;        null v;
    -11h=type v;       null v;
    0>type v;          null v;
    0b]
  }

/ Field as a string.  Numbers are rendered as text, nulls become "".
str:{[d;name]
  v:field[d;name];
  $[isEmpty v;    "";
    10h=type v;   v;
    -11h=type v;  string v;
    -9h=type v;   trimFloat v;
    -7h=type v;   string v;
    -1h=type v;   $[v;"true";"false"];
    ""]
  }

/ Render a float without a trailing decimal point when it is a whole number.
trimFloat:{[f]
  $[f=floor f; string "j"$f; string f]
  }

/ Field as a symbol.  Empty and null fields become the null symbol.
sym:{[d;name]
  `$str[d;name]
  }

/ Field as an int.  Accepts numbers and numeric strings; anything else is null.
int:{[d;name]
  v:field[d;name];
  $[isEmpty v;   0Ni;
    -9h=type v;  "i"$v;
    10h=type v;  "I"$v;
    -7h=type v;  "i"$v;
    0Ni]
  }

/ Field as a float.  Accepts numbers and numeric strings.
float:{[d;name]
  v:field[d;name];
  $[isEmpty v;   0n;
    -9h=type v;  v;
    10h=type v;  "F"$v;
    -7h=type v;  "f"$v;
    0n]
  }

/ Field as a boolean.  Anything missing or null is false.
bool:{[d;name]
  v:field[d;name];
  $[isEmpty v;   0b;
    -1h=type v;  v;
    -9h=type v;  0<>v;
    0b]
  }

/ Field as a list of symbols, e.g. "fantasy_positions":["RB","WR"].
symList:{[d;name]
  v:field[d;name];
  $[isEmpty v;      0#`;
    11h=type v;     v;
    0h=type v;      `$ v;
    10h=type v;     enlist `$v;
    -11h=type v;    enlist v;
    0#`]
  }

/ Field as a list of strings, e.g. "starters":["4034","1234"].
strList:{[d;name]
  v:field[d;name];
  $[isEmpty v;      ();
    0h=type v;      v;
    11h=type v;     string v;
    10h=type v;     enlist v;
    9h=type v;      trimFloat each v;
    ()]
  }

\d .

/ ---------------------------------------------------------------------------
/ Logging.  Deliberately tiny: one line per event, timestamp then level then
/ message, e.g.  2026.09.10D22:30:00 INFO Refreshing league 123456
/ ---------------------------------------------------------------------------

\d .log

format:{[timestamp;level;message]
  (19#string timestamp)," ",level," ",message
  }

write:{[level;message]
  -1 format[.z.p;level;message];
  }

info: write["INFO";]
warn: write["WARN";]
error:write["ERROR";]

\d .
