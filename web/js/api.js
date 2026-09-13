// Every call to the q process goes through here.  Errors from the backend
// arrive as {"error": "..."} and are turned into ordinary Error objects so the
// views can show the message.
const Api = (function () {
  async function request(path, options) {
    let response;
    try {
      response = await fetch(path, options);
    } catch (networkError) {
      throw new Error("Could not reach the local q server. Is it still running?");
    }

    const text = await response.text();
    let payload = null;
    if (text) {
      try {
        payload = JSON.parse(text);
      } catch (parseError) {
        throw new Error(`The server sent a reply that could not be read (HTTP ${response.status}).`);
      }
    }

    if (!response.ok) {
      const message = payload && payload.error ? payload.error : `Request failed (HTTP ${response.status}).`;
      throw new Error(message);
    }

    return payload;
  }

  return {
    league: () => request("/api/league"),
    standings: () => request("/api/standings"),
    teams: () => request("/api/rosters"),
    roster: (rosterId) => request(`/api/roster/${encodeURIComponent(rosterId)}`),
    matchups: (week) => request(week ? `/api/matchups?week=${encodeURIComponent(week)}` : "/api/matchups"),
    players: () => request("/api/players"),
    compare: (playerIds) =>
      request(`/api/compare?players=${encodeURIComponent(playerIds.join(","))}`),
    refresh: () => request("/api/refresh", { method: "POST" }),
    setUp: (username, season) =>
      request(
        `/api/setup?username=${encodeURIComponent(username)}` +
          (season ? `&season=${encodeURIComponent(season)}` : ""),
        { method: "POST" }
      ),
    selectLeague: (leagueId) =>
      request(`/api/select-league?leagueId=${encodeURIComponent(leagueId)}`, { method: "POST" }),
  };
})();
