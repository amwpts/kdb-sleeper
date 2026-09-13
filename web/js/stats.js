// What Sleeper's stat keys mean, and which way round is good.
// Sleeper publishes over 250 different stat keys, so rather than naming every
// one, the common ones are named and the rest are tidied up.
const Stats = (function () {
  const LABELS = {
    gp: "Games played", gms_active: "Games active", gs: "Games started",
    off_snp: "Offensive snaps", def_snp: "Defensive snaps", st_snp: "Special teams snaps",
    tm_off_snp: "Team offensive snaps", tm_def_snp: "Team defensive snaps",
    pass_att: "Pass attempts", pass_cmp: "Completions", pass_inc: "Incompletions",
    pass_yd: "Passing yards", pass_td: "Passing touchdowns", pass_int: "Interceptions thrown",
    pass_2pt: "Passing 2pt", pass_fd: "Passing first downs", pass_lng: "Longest pass",
    pass_rtg: "Passer rating", pass_sack: "Sacks taken", pass_sack_yds: "Yards lost to sacks",
    pass_air_yd: "Air yards", pass_ypa: "Yards per attempt", cmp_pct: "Completion %",
    rush_att: "Carries", rush_yd: "Rushing yards", rush_td: "Rushing touchdowns",
    rush_lng: "Longest run", rush_fd: "Rushing first downs", rush_ypa: "Yards per carry",
    rush_btkl: "Broken tackles", rush_yac: "Yards after contact",
    rec: "Receptions", rec_tgt: "Targets", rec_yd: "Receiving yards",
    rec_td: "Receiving touchdowns", rec_lng: "Longest reception", rec_fd: "Receiving first downs",
    rec_drop: "Drops", rec_air_yd: "Receiving air yards", rec_ypr: "Yards per reception",
    rec_ypt: "Yards per target", rec_yar: "Yards after reception", rec_rz_tgt: "Red zone targets",
    fum: "Fumbles", fum_lost: "Fumbles lost", anytime_tds: "Touchdowns", first_td: "First touchdowns",
    penalty: "Penalties", penalty_yd: "Penalty yards",
    fgm: "Field goals made", fga: "Field goals attempted", fgmiss: "Field goals missed",
    fgm_lng: "Longest field goal", fgm_pct: "Field goal %", fgm_yds: "Field goal yards",
    xpm: "Extra points made", xpa: "Extra points attempted", xpmiss: "Extra points missed",
    kick_pts: "Kicking points",
    sack: "Sacks", int: "Interceptions", def_td: "Defensive touchdowns",
    ff: "Forced fumbles", fum_rec: "Fumbles recovered", tkl: "Tackles",
    tkl_solo: "Solo tackles", tkl_ast: "Assisted tackles", tkl_loss: "Tackles for loss",
    qb_hit: "QB hits", blk_kick: "Blocked kicks", safe: "Safeties",
    pts_allow: "Points allowed", def_pass_def: "Passes defended",
    rank_ppr: "Overall rank (PPR)", rank_half_ppr: "Overall rank (half PPR)",
    rank_std: "Overall rank (standard)", pos_rank_ppr: "Position rank (PPR)",
    pos_rank_half_ppr: "Position rank (half PPR)", pos_rank_std: "Position rank (standard)",
  };

  // Checked in order: the first rule that matches wins.
  const GROUPS = [
    [(k) => k.startsWith("pass_") || k === "cmp_pct", "Passing"],
    [(k) => k.startsWith("rush_"), "Rushing"],
    [(k) => k.startsWith("rec") && k !== "rec_snp", "Receiving"],
    [(k) => k.startsWith("fg") || k.startsWith("xp") || k.startsWith("kick"), "Kicking"],
    [(k) => k.startsWith("def") || k.startsWith("idp") || k.startsWith("tkl") ||
            k.startsWith("sack") || k.startsWith("fan_pts_allow") ||
            ["int", "int_ret_yd", "ff", "ff_misc", "fum_rec", "fum_ret_yd", "qb_hit",
             "blk_kick", "safe", "td", "pts_allow", "fg_blkd"].includes(k), "Defence"],
    [(k) => k.endsWith("_snp") || ["gp", "gms_active", "gs"].includes(k), "Usage"],
    [(k) => k.startsWith("rank_") || k.startsWith("pos_rank_"), "Rankings"],
    [(k) => k.startsWith("bonus_"), "Bonuses"],
    [(k) => k.startsWith("fum") || k.startsWith("penalty") ||
            ["anytime_tds", "first_td"].includes(k), "Misc"],
  ];

  const SECTION_ORDER = ["Usage", "Passing", "Rushing", "Receiving", "Kicking",
                         "Defence", "Rankings", "Bonuses", "Misc", "Other"];

  // Stats where a smaller number is the better one.
  const LOWER_IS_BETTER = new Set([
    "pass_int", "pass_inc", "pass_sack", "pass_sack_yds", "fum", "fum_lost",
    "rec_drop", "penalty", "penalty_yd", "fgmiss", "xpmiss", "pts_allow",
    "rush_tkl_loss", "rush_tkl_loss_yd",
  ]);
  const LOWER_IS_BETTER_PREFIXES = ["rank_", "pos_rank_", "fgmiss", "fan_pts_allow"];

  function label(stat) {
    if (LABELS[stat]) return LABELS[stat];
    const words = String(stat).replace(/_/g, " ").trim();
    return words.charAt(0).toUpperCase() + words.slice(1);
  }

  function group(stat) {
    for (const [matches, name] of GROUPS) {
      if (matches(stat)) return name;
    }
    return "Other";
  }

  // The sections these stats fall into, in reading order.
  function sections(stats) {
    const present = new Set(stats.map(group));
    return SECTION_ORDER.filter((name) => present.has(name));
  }

  function higherIsBetter(stat) {
    if (LOWER_IS_BETTER.has(stat)) return false;
    return !LOWER_IS_BETTER_PREFIXES.some((prefix) => stat.startsWith(prefix));
  }

  // Which of the values is the best one.  Nothing is marked when only one
  // player has the stat, or when they are all the same: there is no comparison
  // to make.
  function bestIndexes(values, higher) {
    const known = values.filter((v) => v !== null && v !== undefined);
    if (known.length < 2) return [];
    const best = higher ? Math.max(...known) : Math.min(...known);
    if (known.every((v) => v === best)) return [];
    const winners = [];
    values.forEach((v, index) => {
      if (v !== null && v !== undefined && v === best) winners.push(index);
    });
    return winners;
  }

  return { label, group, sections, higherIsBetter, bestIndexes };
})();

if (typeof window === "undefined") globalThis.Stats = Stats;
