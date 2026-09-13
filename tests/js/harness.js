// A very small assertion harness, shared by the browser page and any other
// runner.  It records results rather than printing them, so the page can lay
// them out afterwards.
(function (global) {
  const results = [];
  let currentSuite = "";

  function suite(name) {
    currentSuite = name;
  }

  function record(passed, description, detail) {
    results.push({ suite: currentSuite, description, passed, detail: detail || "" });
  }

  function same(a, b) {
    if (Array.isArray(a) && Array.isArray(b)) {
      return a.length === b.length && a.every((item, index) => same(item, b[index]));
    }
    if (a && b && typeof a === "object" && typeof b === "object") {
      const keys = Object.keys(a);
      return keys.length === Object.keys(b).length && keys.every((key) => same(a[key], b[key]));
    }
    return Object.is(a, b);
  }

  function eq(description, actual, expected) {
    const passed = same(actual, expected);
    record(passed, description, passed ? "" : `expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }

  function isTrue(description, actual) {
    eq(description, actual, true);
  }

  function isFalse(description, actual) {
    eq(description, actual, false);
  }

  function summary() {
    return {
      passed: results.filter((r) => r.passed).length,
      failed: results.filter((r) => !r.passed).length,
      results,
    };
  }

  global.TestHarness = { suite, eq, isTrue, isFalse, summary, results };
})(typeof window === "undefined" ? globalThis : window);
