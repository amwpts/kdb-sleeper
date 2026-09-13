// The first-run screen: ask for a Sleeper username so nobody has to edit a
// configuration file by hand.
const SetupView = (function () {
  function field(id, labelText, value, placeholder, wide) {
    const wrapper = document.createElement("div");
    wrapper.className = wide ? "field field-wide" : "field";

    const label = document.createElement("label");
    label.setAttribute("for", id);
    label.textContent = labelText;

    const input = document.createElement("input");
    input.id = id;
    input.type = "text";
    input.value = value || "";
    input.placeholder = placeholder;
    input.autocomplete = "off";
    input.spellcheck = false;

    wrapper.append(label, input);
    return wrapper;
  }

  function render(container) {
    container.innerHTML = "";

    const card = document.createElement("section");
    card.className = "card setup-card";

    const heading = document.createElement("h2");
    heading.textContent = "Set up your league";

    const blurb = document.createElement("p");
    blurb.className = "setup-blurb";
    blurb.textContent =
      "Enter your Sleeper username and this will find your leagues for the season and download one. " +
      "Nothing is sent anywhere except to Sleeper, and your answer is saved locally in config/config.json.";

    const form = document.createElement("form");
    form.className = "setup-form";
    form.noValidate = true;

    const usernameField = field("setup-username", "Sleeper username", App.state.league.username, "e.g. gridironGuru", true);
    const seasonField = field("setup-season", "Season", App.state.league.season, "2026", false);

    const submit = document.createElement("button");
    submit.type = "submit";
    submit.className = "button button-primary";
    const spinner = document.createElement("span");
    spinner.className = "spinner";
    spinner.setAttribute("aria-hidden", "true");
    const submitLabel = document.createElement("span");
    submitLabel.textContent = "Find my leagues";
    submit.append(spinner, submitLabel);

    const error = document.createElement("p");
    error.className = "setup-error";
    error.hidden = true;
    error.setAttribute("role", "alert");

    const hint = document.createElement("p");
    hint.className = "setup-hint";
    hint.textContent =
      "Your username is the one you sign in to Sleeper with, not your display name. " +
      "If you would rather not use a username, put a league id in config/config.json instead.";

    form.append(usernameField, seasonField, submit);
    card.append(heading, blurb, form, error, hint);
    container.appendChild(card);

    const usernameInput = usernameField.querySelector("input");
    const seasonInput = seasonField.querySelector("input");
    usernameInput.focus();

    function setBusy(busy) {
      submit.disabled = busy;
      submit.classList.toggle("is-busy", busy);
      submitLabel.textContent = busy ? "Looking you up…" : "Find my leagues";
      usernameInput.disabled = busy;
      seasonInput.disabled = busy;
    }

    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      if (submit.disabled) return;

      const username = usernameInput.value.trim();
      if (!username) {
        error.hidden = false;
        error.textContent = "Enter your Sleeper username to continue.";
        usernameInput.focus();
        return;
      }

      error.hidden = true;
      setBusy(true);

      try {
        const result = await Api.setUp(username, seasonInput.value.trim());
        if (result.status === "needsLeagueSelection") {
          App.showLeaguePicker(result.choices);
          return;
        }
        await App.reload();
        App.showToast(`Downloaded your league. Week ${result.week} is loaded.`, "success");
      } catch (failure) {
        error.hidden = false;
        error.textContent = failure.message;
        usernameInput.focus();
      } finally {
        setBusy(false);
      }
    });
  }

  return { render };
})();
