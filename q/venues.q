/ Where each NFL team plays, and what is over their heads.
/ Sleeper publishes nothing at all about stadiums or the weather, so this is
/ hand maintained reference data rather than anything downloaded.  It only
/ answers "is this game played indoors": anything more (temperature, wind,
/ rain) needs a weather service, which this application deliberately does not
/ reach out to.
/ Correct a row here if a team moves or a roof changes.

\d .venues

grounds:([team:`$()] ground:(); roof:`$());

grounds:grounds upsert flip `team`ground`roof!flip (
  (`ARI; "State Farm Stadium";           `retractable);
  (`ATL; "Mercedes-Benz Stadium";        `retractable);
  (`BAL; "M&T Bank Stadium";             `outdoor);
  (`BUF; "Highmark Stadium";             `outdoor);
  (`CAR; "Bank of America Stadium";      `outdoor);
  (`CHI; "Soldier Field";                `outdoor);
  (`CIN; "Paycor Stadium";               `outdoor);
  (`CLE; "Huntington Bank Field";        `outdoor);
  (`DAL; "AT&T Stadium";                 `retractable);
  (`DEN; "Empower Field at Mile High";   `outdoor);
  (`DET; "Ford Field";                   `indoor);
  (`GB;  "Lambeau Field";                `outdoor);
  (`HOU; "NRG Stadium";                  `retractable);
  (`IND; "Lucas Oil Stadium";            `retractable);
  (`JAX; "EverBank Stadium";             `outdoor);
  (`KC;  "GEHA Field at Arrowhead";      `outdoor);
  (`LAC; "SoFi Stadium";                 `indoor);
  (`LAR; "SoFi Stadium";                 `indoor);
  (`LV;  "Allegiant Stadium";            `indoor);
  (`MIA; "Hard Rock Stadium";            `outdoor);
  (`MIN; "U.S. Bank Stadium";            `indoor);
  (`NE;  "Gillette Stadium";             `outdoor);
  (`NO;  "Caesars Superdome";            `indoor);
  (`NYG; "MetLife Stadium";              `outdoor);
  (`NYJ; "MetLife Stadium";              `outdoor);
  (`PHI; "Lincoln Financial Field";      `outdoor);
  (`PIT; "Acrisure Stadium";             `outdoor);
  (`SEA; "Lumen Field";                  `outdoor);
  (`SF;  "Levi's Stadium";               `outdoor);
  (`TB;  "Raymond James Stadium";        `outdoor);
  (`TEN; "Nissan Stadium";               `outdoor);
  (`WAS; "Northwest Stadium";            `outdoor));

/ The roof over a team's home ground, or the null symbol for a team we have no
/ record of.
roofFor:{[team]
  match:grounds team;
  $[null match`roof; `; match`roof]
  }

groundFor:{[team]
  match:grounds team;
  $[null match`roof; ""; match`ground]
  }

\d .
