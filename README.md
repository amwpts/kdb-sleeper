# sleeper-kdb

A small local web application for looking at your Sleeper fantasy football
league. It downloads your league from the public Sleeper API, stores it in
kdb+/q tables on disk, and serves a dashboard from the same q process.

Everything is q: ingestion, the database, the JSON API and the web server. The
browser side is hand written HTML, CSS and vanilla JavaScript. There is no
Node, npm, Python, Docker or JavaScript framework anywhere in the project.

```
Sleeper API  ->  q ingestion  ->  kdb+ tables  ->  q HTTP server  ->  JSON API  ->  browser
```

## What you get

No configuration file to write: start it, and the page asks for your Sleeper
username.


* **Overview** – current week, league size, highest scoring team, best record,
  this week's games and the top of the table.
* **Standings** – a sortable, filterable table with your own team highlighted.
* **Rosters** – pick a team, see its record and its players with position and
  injury badges, sortable and searchable.
* **Matchups** – one card per game with the leader highlighted, and week
  navigation.
* **Players** – a data grid rather than a long page: the table keeps its own
  scrollbars, so the headings, the player column and the sideways scrollbar
  stay in reach however many rows there are. Everyone worth knowing about in
  the league, showing who has
  them and who is still available, with a full scoring grid: season points,
  points per game, the last three games, this week's score, this week's and
  next week's projection, the next three weeks, the season and rest of season
  projection, and how far above or below projection a player has been running.
  Every column sorts — numbers open biggest first, and rows with nothing in a
  column stay at the bottom whichever way it is sorted — and there are quick
  filters for availability and position.
* **Compare** – tick any two to six players on the Players page and put them
  side by side: the fantasy numbers, then their whole season as one list per
  player — every week, who they play, whether it is played under a roof, what
  they were projected and what they scored — and finally every raw stat Sleeper
  reports for them, grouped into passing, rushing, receiving, kicking, defence
  and the rest. The better number in each row is picked out, allowing for the
  stats where a smaller number is the better one.

  Every week has a winner marked: a week that has been played is judged on what
  was actually scored, one still to come on the projection. Choose a stretch of
  weeks — the next three, the rest of the season, or any two weeks you like —
  and the total, the average and the weeks won over that stretch are worked out
  for each player, so "who is better over the next month" takes one glance.
* **Refresh** – one button that re-downloads the league and updates the page.

Data is kept on disk, so restarting q does not lose anything, and a failed
refresh never destroys what you already had.

## Prerequisites

* **kdb+/q** and any license required by your KX distribution. Follow the
  [KX installation instructions](https://code.kx.com/q/learn/install/).
  For native Windows, use the **Windows kdb+ build (`w64`)**. KDB-X currently
  [does not support native Windows installation](https://code.kx.com/kdb-x/get_started/kdb-x-install.html).
* **curl** on your executable search path. On Windows, check `curl.exe --version`
  in PowerShell; on macOS/Linux, check `curl --version` in a terminal.
* Windows launchers use **Windows PowerShell 5.1** (`powershell.exe`).

No Node, npm, Python or Docker is needed to run the app. No Sleeper API key is
needed: the API is public and read only. An internet connection is needed to
download or refresh league data. q uses curl for HTTPS requests.

## Getting started

Download the repository ZIP and **extract it first**, or clone the repository
with Git. Keep the whole project folder together, including `q`, `web`,
`config` and `scripts`. Use a local folder you can write to.

### Windows

1. Install Windows kdb+/q using the KX instructions above. A typical layout is
   `C:\q\w64\q.exe`, with `q.k` and the license file in `C:\q`.
2. In Windows **Edit environment variables for your account**, set `QHOME` to
   the installation folder (for example `C:\q`). For terminal use, also add
   `C:\q\w64` to your user `Path`. Reopen PowerShell after changing these.
   Run `q.exe` to check that q starts without a license or installation error;
   type `exit 0` to leave q. Check `curl.exe --version` too.
3. Double-click **`start.bat`** in the extracted project folder. It starts the
   server in the background and opens your default browser.
4. Enter your Sleeper username and select your league when prompted.
5. Double-click **`stop.bat`** when you want to stop the server. Closing the
   browser does not stop it.

From PowerShell in the project folder, the equivalent commands are:

```powershell
.\start.bat
.\stop.bat
```

The launcher finds `q.exe` on `Path`, under `%QHOME%\w64`, under
`%USERPROFILE%\q\w64`, or at `C:\q\w64\q.exe`. It handles project folders
containing spaces. The `.bat` files call `scripts/windows.ps1` with a
process-only execution-policy setting; they do not change your saved policy.
If your organisation blocks PowerShell scripts, ask its IT administrator.

### macOS and Linux

Install kdb+/q, then open a terminal in the project folder and run:

```bash
./start.command
```

On macOS you can also **double-click `start.command`** in Finder. If extracting
a ZIP lost executable permissions, run `chmod +x start.command stop.command`.
The launcher finds q on `PATH`, in `$QHOME/m64` or `$QHOME/l64`, in `~/.kx/bin`,
or under `~/q`.

Stop the background server with:

```bash
./stop.command
```

The `.command` files require Bash and Unix utilities; use the `.bat` files for
native Windows.

### First launch and subsequent launches

The dashboard opens at <http://localhost:8080> (unless you change the configured
port). There is nothing to configure before starting: enter your Sleeper
username, then choose a league. Your selection is saved in `config/config.json`
and downloaded data is saved under `data/` for the next launch.

Starting again opens the existing server. Changes to q source files trigger a
restart. The Windows launcher also restarts when the configured port changes
and allows up to two minutes for initial startup and downloads.

Logs are in `data/server.log`; Windows also writes `data/server.error.log`.
If Windows startup fails, the launcher window stays open to show the error.
The Windows stop command only stops the process recorded by that project's
Windows launcher; it checks process identity before stopping it.

### Sharing with someone else

Share a clean repository clone or ZIP. If you copy your working folder, omit
`data/` and `config/config.json` so the recipient starts with their own league.
Include `config/config.example.json` and the complete `scripts/` folder.
Each recipient must install their own kdb+/q runtime and required license.

### Starting it by hand

From the project folder, with q on your executable search path:

```bash
q q/main.q
```

On Windows, use `q.exe q/main.q`. This runs in the foreground; type `exit 0`
in that q session to stop it. The Windows stop launcher does not manage servers
started by hand.

### Configuration

You do not have to touch this file — the setup screen writes it for you — but
it is plain JSON if you would rather fill it in yourself. It holds your own
settings and is never committed:

```json
{
  "username": "mySleeperUsername",
  "season": "2026",
  "leagueId": "",
  "port": 8080
}
```

| Field      | Meaning                                                                   |
| ---------- | ------------------------------------------------------------------------- |
| `username` | Your Sleeper username. Used to find your leagues when `leagueId` is empty. |
| `season`   | Optional. Defaults to the current NFL season.                             |
| `leagueId` | Optional. Set it to skip the lookup and go straight to one league.        |
| `port`     | Optional. Defaults to 8080.                                               |

If the file is missing or has neither a `username` nor a `leagueId`, the
application still starts and shows the setup screen.

A `config/config.example.json` is included if you prefer to start from a copy:

```bash
cp config/config.example.json config/config.json
```

**Which league is used?**

1. `leagueId` from the configuration file, if it is set.
2. Otherwise the league already stored in `data/`, so your choice sticks.
3. Otherwise your leagues are looked up from your username. If you are in
   exactly one, it is used. If you are in several, the browser shows a picker,
   and whichever you choose is written back to `config/config.json`.

Your league id is also visible in the Sleeper web app's address bar:
`https://sleeper.com/leagues/<leagueId>/...`

## Running the tests

The q unit tests are the main suite. They never touch the network: every
parsing and transformation test runs against the small JSON fixtures in
`tests/fixtures/`.

```bash
q tests/runTests.q -q          # exits non-zero on failure
```

The browser side logic (sorting, filtering, formatting) has its own tests that
need nothing but a browser:

```bash
open tests/js/index.html       # macOS; or just open the file in any browser
```

The q test runner and demo currently use Unix shell commands for temporary
directory cleanup; run those suites on macOS/Linux (or in WSL with Linux q).
Native Windows launch testing must be performed separately.

Two extra suites are not part of the normal run:

```bash
# Hits the real Sleeper API, so it needs an internet connection.
q tests/integration/test_live_sleeper.q -q

# Add a real league id to test league endpoints too.
q tests/integration/test_live_sleeper.q -q -leagueId 1124567890123456789

# Runs the whole application against the test fixtures, with no Sleeper
# account needed, on http://localhost:8099
q tests/integration/demo_server.q -q
```

## Architecture

```
q/util.q        logging, and safe reads of Sleeper's inconsistent JSON
q/config.q      reading and validating config/config.json
q/schema.q      every table definition, in one place
q/transform.q   parsed JSON -> q tables.  Pure, and the most heavily tested part
q/views.q       tables -> the shapes the browser needs (standings, matchups...)
q/storage.q     saving to and loading from data/
q/http.q        the only code that touches the network (curl)
q/sleeper.q     Sleeper endpoints, one function each
q/refresh.q     download a whole league and commit it in one go
q/api.q         the JSON API: (method;path) -> response
q/web.q         static files and .z.ph / .z.pp wiring
q/main.q        entry point

start.command   macOS/Linux: start in the background and open a browser
stop.command    macOS/Linux: stop it again
start.bat       Windows: start in the background and open a browser
stop.bat        Windows: stop it again
scripts/windows.ps1  shared Windows launcher implementation

web/index.html      the shell
web/css/style.css   the theme, driven by CSS variables
web/js/api.js       calls to the q process
web/js/tables.js    reusable sorting, filtering and table rendering
web/js/format.js    shared formatting helpers
web/js/app.js       state, navigation, refresh, loading and error states
web/js/views/*.js   one file per section, plus the first-run setup screen
```

Two design points are worth knowing:

* **Retrieval, parsing, transformation and storage are separate.** Only
  `q/http.q` performs IO, so every transform can be tested from a fixture. The
  whole ingestion path is testable too, because `.sleeper.transport` is a
  single function that tests swap for a stub.
* **A missing projection is not a zero.** Sleeper sends an entry for thousands
  of players it does not project, and a player's bye week arrives the same way:
  an entry with no points. Neither is stored, so a week with no row means "not
  projected". Sums treat that as nothing scored, which is right; a player with
  no projection at all shows a dash rather than a misleading `0.0`. The one
  deliberate exception is the next-three-week average, where a bye really does
  cost you the points, so the total is divided by the weeks in the window
  rather than by the weeks projected.
* **Season and rest-of-season projections are added up week by week.** Sleeper
  also publishes a season projection directly, but it does not agree with the
  sum of its own weekly numbers (a mean difference of about 8 points, and up to
  177 for one player). Summing the weekly figures at least keeps the columns
  consistent with each other, so rest-of-season can never exceed the season.
* **Scoring is read, not recalculated.** Sleeper publishes each player's
  season points already worked out three ways: standard, half point per
  reception and full PPR. All three are stored, and the league's own
  `scoring_settings` decide which one is shown, so there is no scoring engine
  to get subtly wrong. Season stats are a small download and come with every
  refresh, unlike the player reference data.
* **Raw stats are stored long, not wide.** Sleeper publishes over 250
  different stat keys and only forty or so apply to any one player, so they are
  kept one row per player per stat. That means a comparison can show everything
  Sleeper knows about a player without the schema having to know the name of
  every stat in advance.
* **Weeks are only downloaded once.** A week that has finished never changes,
  so its stats and projections are fetched once and kept. The week in progress
  and the weeks still to come are fetched again on each refresh. That makes the
  first refresh the slowest (about five seconds, with eighteen weeks of
  projections to collect) and every later one cheaper as the season goes on.
* **The player pool is worked out per league.** `/api/players` does not send
  all 12,000 NFL players to the browser. It sends the ones on an NFL team in a
  position the league actually plays, plus anybody already on a roster there,
  which is around 900 rows. A league that rosters defensive players gets those
  positions added automatically, so an IDP league still sees its free agents.
* **A refresh is all or nothing.** Everything is downloaded and transformed
  first, and only committed to memory and disk once every step has succeeded.
  If Sleeper is down or sends something unexpected, the previous data stays
  exactly as it was and the browser shows the error.

### Data model

| Table           | One row per                | Notes                                        |
| --------------- | -------------------------- | -------------------------------------------- |
| `league`        | the configured league      | name, season, status, team count             |
| `users`         | manager in the league      | username, display name, team name            |
| `rosters`       | team                       | record and points for/against                 |
| `rosterPlayers` | roster/player relationship | starter and reserve flags, line-up slot      |
| `players`       | NFL player                 | name, team, position, injury status          |
| `matchups`      | roster per week            | week, matchup id, points                     |
| `playerStats`   | NFL player                 | games played and season fantasy points       |
| `playerWeekStats` | player per week          | what they actually scored that week          |
| `playerWeekProjections` | player per week    | what Sleeper projected for that week         |
| `playerStatLines` | player and stat          | every raw stat Sleeper reports                |
| `schedule`      | team per game              | who they play each week, and where            |

`q/venues.q` holds one more table that is not downloaded at all: the ground
each team plays at and whether it has a roof.
| `refreshLog`    | dataset                    | when it was last downloaded                  |

Identifiers that repeat (league, roster, user, player, NFL team, position) are
symbols; free text such as team and player names is kept as strings; counts are
ints, points are floats.

You can open the database in any q session:

```q
q)\l q/schema.q
q)\l q/storage.q
q).store.init "data"
q)select rosterId, wins, losses, pointsFor from .db.rosters
```

### Where the data lives

`data/` in the repository, one serialised file per table:

```
data/league   data/users       data/rosters          data/rosterPlayers
data/players  data/matchups    data/playerStats      data/refreshLog
data/playerWeekStats           data/playerWeekProjections
```

The directory is created on first run and is git-ignored. Deleting it simply
means the next start downloads everything again.

The `/players/nfl` endpoint is roughly 15 MB, so it is downloaded at most once
a day. `refreshLog` records when it was last fetched, and a refresh only asks
for it again once that is more than a day old.

### What Sleeper does not tell you

Sleeper's schedule carries only the date, the two teams, a game id and whether
the game has been played. There is **no stadium, no venue, no weather and no
temperature** anywhere in its API.

Whether a game is played indoors does not need an API, though, because it only
depends on the home team's ground. `q/venues.q` holds that as a small
hand-maintained table — the ground and its roof for all 32 teams — and the
comparison screen marks each fixture `DOME` or `ROOF` accordingly. It is
ordinary reference data rather than anything downloaded, so correct a row there
if a team moves or a roof changes.

Actual weather — temperature, wind, rain — would need a weather service. This
application deliberately talks to nothing but Sleeper, so it does not fetch it.

## HTTP API

| Method | Path                                | Returns                                         |
| ------ | ----------------------------------- | ----------------------------------------------- |
| GET    | `/api/league`                       | league, season, current week, last refresh time |
| GET    | `/api/standings`                    | ranked teams with records and points            |
| GET    | `/api/rosters`                      | every team, for the roster picker               |
| GET    | `/api/roster/<rosterId>`            | one team and its players                        |
| GET    | `/api/matchups?week=<n>`            | one week's matchups, grouped into pairs         |
| GET    | `/api/players`                      | the player pool, with availability and scoring  |
| GET    | `/api/compare?players=<a,b,c>`      | a handful of players side by side               |
| POST   | `/api/refresh`                      | re-download the league                          |
| POST   | `/api/setup?username=<name>`        | find a user's leagues and set the application up |
| POST   | `/api/select-league?leagueId=<id>`  | choose a league and download it                 |

Errors come back as `{"error": "..."}` with a sensible status code.

The server listens on `127.0.0.1` only. It reads your league and writes your
configuration file, so it is deliberately not reachable from the rest of your
network.

## Troubleshooting

**"Could not find 'q'"** – install kdb+/q and check that typing `q` in a
terminal starts it. On Windows check `q.exe`, `QHOME` and the `w64` folder
listed in the setup instructions above. On macOS/Linux the launcher also looks
in `$QHOME`, `~/.kx/bin` and `~/q`.

**"there is no Sleeper user with that username"** – check the spelling. It is
your Sleeper *username*, not your display name.

**"no leagues found for ... in the ... season"** – the season in your
configuration is probably not one you played. Set `season` to a year you have a
league in, or set `leagueId` directly.

**"could not reach Sleeper"** – you are offline, or `curl` is missing. Anything
already downloaded is still shown.

**The port is already in use** – change `port` in `config/config.json`, or
stop whatever else is using it. `./stop.command` (macOS/Linux) or `stop.bat` (Windows) stops a server its launcher
started.

**Starting it again does nothing** – it is probably already running.
`./start.command` or `start.bat` will say so and just open the browser.

**A change to the q code seems to have no effect** – q reads its source once,
at start-up, so a running server keeps serving the code it started with.
`./start.command` and `start.bat` notice this and restart for you. Files under `web/` are
read on every request, so a change there only needs a browser reload.

## Scope

This is version 1: a clean, tested foundation. It deliberately has no
authentication, accounts, projections, trade analysis, waiver advice or
historical analytics.
