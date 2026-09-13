// Reusable table behaviour: comparing, sorting, filtering, and rendering.
// The comparing/sorting/filtering functions are pure so that they can be
// tested on their own (see tests/js/).
const Tables = (function () {
  function isEmpty(value) {
    return value === null || value === undefined || value === "";
  }

  // Numbers compare numerically, text alphabetically and case insensitively,
  // and anything missing sorts to the end.
  function compareValues(a, b) {
    if (isEmpty(a) && isEmpty(b)) return 0;
    if (isEmpty(a)) return 1;
    if (isEmpty(b)) return -1;
    if (typeof a === "boolean" || typeof b === "boolean") {
      return (a === true ? 1 : 0) - (b === true ? 1 : 0);
    }
    if (typeof a === "number" && typeof b === "number") {
      return a < b ? -1 : a > b ? 1 : 0;
    }
    const left = String(a).toLowerCase();
    const right = String(b).toLowerCase();
    return left < right ? -1 : left > right ? 1 : 0;
  }

  // Returns a new array; rows that compare equal keep their original order.
  // Rows with nothing in the column always go to the bottom, whichever way the
  // column is sorted: reversing a table should not bring a block of dashes to
  // the top.
  function sortRows(rows, key, direction) {
    const factor = direction === "desc" ? -1 : 1;
    return rows
      .map((row, index) => ({ row, index }))
      .sort((a, b) => {
        const left = a.row[key];
        const right = b.row[key];
        const leftEmpty = isEmpty(left);
        const rightEmpty = isEmpty(right);
        if (leftEmpty || rightEmpty) {
          if (leftEmpty && rightEmpty) return a.index - b.index;
          return leftEmpty ? 1 : -1;
        }
        const result = compareValues(left, right);
        return result !== 0 ? result * factor : a.index - b.index;
      })
      .map((entry) => entry.row);
  }

  // Clicking the current column reverses it.  Clicking a new one starts in
  // whichever direction is most useful for that column: numbers biggest first,
  // text A to Z.
  function nextSortDirection(currentKey, currentDirection, clickedKey, preferred) {
    if (currentKey !== clickedKey) return preferred || "asc";
    return currentDirection === "asc" ? "desc" : "asc";
  }

  // The direction a column should take when it is first clicked.
  function preferredDirection(column) {
    if (column.defaultSort) return column.defaultSort;
    return column.numeric ? "desc" : "asc";
  }

  function filterRows(rows, query, fields) {
    const needle = String(query || "").trim().toLowerCase();
    if (!needle) return rows.slice();
    return rows.filter((row) =>
      fields.some((field) => String(row[field] ?? "").toLowerCase().includes(needle))
    );
  }

  // Keep a chosen week inside the weeks we actually hold data for.
  function clampWeek(week, weeks) {
    if (!weeks || weeks.length === 0) return 1;
    const lowest = Math.min(...weeks);
    const highest = Math.max(...weeks);
    if (week < lowest) return lowest;
    if (week > highest) return highest;
    return week;
  }

  // -------------------------------------------------------------------------
  // Rendering
  // -------------------------------------------------------------------------

  // Let a table use the rest of the window rather than running off the bottom
  // of the page.  A short table is unaffected, since this only sets a ceiling.
  const BOTTOM_GUTTER = 24;
  const SMALLEST_USEFUL_TABLE = 240;

  function fitScrollers() {
    for (const scroller of document.querySelectorAll(".table-scroll")) {
      const available = window.innerHeight - scroller.getBoundingClientRect().top - BOTTOM_GUTTER;
      scroller.style.maxHeight = Math.max(SMALLEST_USEFUL_TABLE, Math.round(available)) + "px";
    }
  }

  // Draw a sortable table.  `config` is:
  //   columns:  [{ key, label, numeric, render(row) }]
  //   rows:     already sorted and filtered
  //   sortKey, sortDirection
  //   onSort(key)
  //   rowClass(row)   optional
  //   emptyMessage    shown instead of the table when there are no rows
  function render(container, config) {
    container.innerHTML = "";

    if (!config.rows.length) {
      const empty = document.createElement("p");
      empty.className = "empty-state";
      empty.textContent = config.emptyMessage || "Nothing to show.";
      container.appendChild(empty);
      return;
    }

    const scroller = document.createElement("div");
    scroller.className = "table-scroll";

    const table = document.createElement("table");
    table.className = "data-table";
    // A wide table keeps its first column in view while it is scrolled.
    if (config.stickyFirstColumn) table.classList.add("sticky-first");

    const head = document.createElement("thead");
    const headRow = document.createElement("tr");

    for (const column of config.columns) {
      const cell = document.createElement("th");
      if (column.numeric) cell.classList.add("numeric");
      if (column.projection) cell.classList.add("projection");

      const button = document.createElement("button");
      button.type = "button";
      button.className = "sort-button";
      button.textContent = column.label;
      if (column.title) button.title = column.title;

      const isSorted = config.sortKey === column.key;
      if (isSorted) {
        button.classList.add("sorted");
        cell.setAttribute("aria-sort", config.sortDirection === "asc" ? "ascending" : "descending");
        const indicator = document.createElement("span");
        indicator.className = "sort-indicator";
        indicator.textContent = config.sortDirection === "asc" ? "▲" : "▼";
        button.appendChild(indicator);
      }

      button.addEventListener("click", () => config.onSort(column.key, preferredDirection(column)));
      cell.appendChild(button);
      headRow.appendChild(cell);
    }

    head.appendChild(headRow);
    table.appendChild(head);

    const body = document.createElement("tbody");
    for (const row of config.rows) {
      const line = document.createElement("tr");
      const extraClass = config.rowClass ? config.rowClass(row) : "";
      if (extraClass) line.className = extraClass;

      for (const column of config.columns) {
        const cell = document.createElement("td");
        if (column.numeric) cell.classList.add("numeric");
        if (column.projection) cell.classList.add("projection");
        const content = column.render(row);
        if (content instanceof Node) {
          cell.appendChild(content);
        } else {
          cell.textContent = content;
        }
        line.appendChild(cell);
      }
      body.appendChild(line);
    }

    table.appendChild(body);
    scroller.appendChild(table);
    container.appendChild(scroller);
    fitScrollers();
  }

  return { compareValues, sortRows, nextSortDirection, preferredDirection, filterRows, clampWeek, render, fitScrollers };
})();

if (typeof window === "undefined") globalThis.Tables = Tables;
