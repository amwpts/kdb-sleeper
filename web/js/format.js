// Formatting helpers shared by every view.  All pure, all unit tested.
const Format = (function () {
  const SEVERE_INJURIES = ["out", "ir", "pup", "sus", "dnr", "na", "cov"];

  function points(value) {
    const number = Number(value);
    return (Number.isFinite(number) ? number : 0).toFixed(2);
  }

  // Fantasy points are shown to one decimal place, as everywhere else in
  // fantasy football.  A player who has not played shows a dash instead of a
  // row of zeroes.
  function score(value, gamesPlayed) {
    if (value === null || value === undefined) return "—";
    if (gamesPlayed === 0) return "—";
    const number = Number(value);
    return Number.isFinite(number) ? number.toFixed(1) : "—";
  }

  // Over and under a projection reads much better with its sign.
  function signed(value) {
    if (value === null || value === undefined) return "—";
    const number = Number(value);
    if (!Number.isFinite(number)) return "—";
    return (number > 0 ? "+" : "") + number.toFixed(1);
  }

  function record(wins, losses, ties) {
    const w = wins || 0;
    const l = losses || 0;
    const t = ties || 0;
    return t ? `${w}-${l}-${t}` : `${w}-${l}`;
  }

  function slug(text) {
    return String(text || "").toLowerCase().replace(/[^a-z0-9]+/g, "-");
  }

  function positionClass(position) {
    return position ? `badge badge-${slug(position)}` : "badge badge-none";
  }

  function injuryClass(status) {
    if (!status) return "";
    const severity = SEVERE_INJURIES.includes(String(status).toLowerCase()) ? "out" : "questionable";
    return `badge badge-injury badge-${severity}`;
  }

  function injuryLabel(status) {
    return status ? String(status).toUpperCase() : "";
  }

  // "5 minutes ago", "2 hours ago", or a date once it is more than a week old.
  function relativeTime(isoText, now) {
    if (!isoText) return "never";
    const then = new Date(isoText);
    if (Number.isNaN(then.getTime())) return "never";
    const reference = now || new Date();
    const seconds = Math.round((reference.getTime() - then.getTime()) / 1000);

    if (seconds < 45) return "just now";
    const minutes = Math.round(seconds / 60);
    if (minutes < 60) return `${minutes} minute${minutes === 1 ? "" : "s"} ago`;
    const hours = Math.round(minutes / 60);
    if (hours < 24) return `${hours} hour${hours === 1 ? "" : "s"} ago`;
    const days = Math.round(hours / 24);
    if (days < 7) return `${days} day${days === 1 ? "" : "s"} ago`;
    return then.toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" });
  }

  return { points, score, signed, record, positionClass, injuryClass, injuryLabel, relativeTime, slug };
})();

if (typeof window === "undefined") globalThis.Format = Format;
