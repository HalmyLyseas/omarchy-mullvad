const { readFileSync } = require("node:fs");
const { join } = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const root = join(__dirname, "..");
const workflow = readFileSync(join(root, ".github/workflows/test.yml"), "utf8");
const ciLocal = readFileSync(join(root, "tests/ci-local"), "utf8");
const uiRunner = readFileSync(join(root, "tests/probe/run-ui"), "utf8");

test("CI validates only the exact Omarchy 4.0.4 tag", () => {
    assert.match(workflow, /git clone --depth 1 --branch v4\.0\.4 https:\/\/github\.com\/basecamp\/omarchy\.git/);
    assert.match(workflow, /describe --tags --exact-match[^\n]*" = v4\.0\.4/);
    assert.doesNotMatch(workflow, /v4\.0\.3|matrix:/);
    assert.doesNotMatch(workflow, /pacman -Swdd --noconfirm omarchy/);
});

test("local gate and UI runner share overridable Omarchy sources", () => {
    assert.match(ciLocal, /OMARCHY_SHELL_DIR:-\/usr\/share\/omarchy\/shell/);
    assert.match(ciLocal, /OMARCHY_PLUGIN_VALIDATOR/);
    assert.match(uiRunner, /OMARCHY_SHELL_DIR:-\/usr\/share\/omarchy\/shell/);
    assert.doesNotMatch(ciLocal, /-I \/usr\/share\/omarchy\/shell/);
    assert.doesNotMatch(uiRunner, /ln -s \/usr\/share\/omarchy\/shell/);
});
