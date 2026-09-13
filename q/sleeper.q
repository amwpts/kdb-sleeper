/ The Sleeper API.  Every call is a url built here, fetched through the
/ transport, and handed straight to a transform.
/ Sleeper is read-only and needs no key or authentication.

\d .sleeper

baseUrl:"https://api.sleeper.app/v1";

/ The schedule is the one endpoint Sleeper does not put under /v1.
siteUrl:"https://api.sleeper.app";

userUrl:{[username]           baseUrl,"/user/",username}
leaguesUrl:{[userId;season]   baseUrl,"/user/",userId,"/leagues/nfl/",season}
leagueUrl:{[leagueId]         baseUrl,"/league/",leagueId}
leagueUsersUrl:{[leagueId]    leagueUrl[leagueId],"/users"}
leagueRostersUrl:{[leagueId]  leagueUrl[leagueId],"/rosters"}
matchupsUrl:{[leagueId;week]  leagueUrl[leagueId],"/matchups/",string week}
playersUrl:{[]                baseUrl,"/players/nfl"}
stateUrl:{[]                  baseUrl,"/state/nfl"}
seasonStatsUrl:{[season]      baseUrl,"/stats/nfl/regular/",season}
weekStatsUrl:{[season;week]   baseUrl,"/stats/nfl/regular/",season,"/",string week}
weekProjectionsUrl:{[season;week] baseUrl,"/projections/nfl/regular/",season,"/",string week}
scheduleUrl:{[season]         siteUrl,"/schedule/nfl/regular/",season}

/ The single seam between the application and the network.  Tests replace this
/ with a stub that replays fixture text.
transport:.http.request;

fetch:{[url;what]
  .http.json[transport url; what]
  }

/ ---------------------------------------------------------------------------
/ Endpoints
/ ---------------------------------------------------------------------------

user:{[username]
  .tf.userProfile fetch[userUrl username; "user \"",username,"\""]
  }

leagues:{[userId;season]
  .tf.leagueList fetch[leaguesUrl[userId;season]; "leagues for the ",season," season"]
  }

league:{[leagueId]
  .tf.league fetch[leagueUrl leagueId; "league ",leagueId]
  }

leagueUsers:{[leagueId]
  .tf.users[`$leagueId; fetch[leagueUsersUrl leagueId; "the users in league ",leagueId]]
  }

/ The rosters payload feeds two tables, so it is fetched once and transformed
/ twice by the refresh.
rostersPayload:{[leagueId]
  fetch[leagueRostersUrl leagueId; "the rosters in league ",leagueId]
  }

leagueRosters:{[leagueId]
  .tf.rosters[`$leagueId; rostersPayload leagueId]
  }

matchups:{[leagueId;week]
  .tf.matchups[`$leagueId; week; fetch[matchupsUrl[leagueId;week]; "week ",string[week]," matchups"]]
  }

players:{[]
  .tf.players fetch[playersUrl[]; "the NFL player list"]
  }

state:{[]
  .tf.state fetch[stateUrl[]; "the current NFL week"]
  }

/ The season stats payload feeds two tables, so it is fetched once and
/ transformed twice, the same way the rosters payload is.
seasonStatsPayload:{[season]
  fetch[seasonStatsUrl season; "the ",season," season stats"]
  }

seasonStats:{[season]
  .tf.playerStats[season; seasonStatsPayload season]
  }

schedule:{[season]
  .tf.schedule[season; fetch[scheduleUrl season; "the ",season," schedule"]]
  }

weekStats:{[season;week]
  .tf.weekStats[season; week; fetch[weekStatsUrl[season;week]; "week ",string[week]," stats"]]
  }

weekProjections:{[season;week]
  .tf.weekProjections[season; week; fetch[weekProjectionsUrl[season;week]; "week ",string[week]," projections"]]
  }

\d .
