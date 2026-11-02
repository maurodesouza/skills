#!/usr/bin/env node
// Static checks for the command-bus-architecture rules.
// Usage: node check-architecture.mjs <src-dir>
// Exit code 0 = no violations, 1 = violations found, 2 = usage error.
// Assumes Biome-formatted code (4-space indentation), as the architecture requires.

import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative, sep } from "node:path";

const root = process.argv[2];

if (!root || !statSync(root, { throwIfNoEntry: false })?.isDirectory()) {
	console.error("usage: node check-architecture.mjs <src-dir>");
	process.exit(2);
}

const IGNORED_DIRS = new Set(["node_modules", "dist", ".output", ".tanstack"]);
// Vendored UI (Fragiola/shadcn) and the Command System reference are not app code.
const VENDORED = [
	`${sep}components${sep}ui${sep}`,
	`${sep}components${sep}atoms${sep}`,
	`${sep}components${sep}families${sep}`,
	`${sep}lib${sep}command${sep}`,
];

const violations = [];

function report(file, line, rule, message) {
	violations.push({ file: relative(process.cwd(), file), line, rule, message });
}

function walk(dir) {
	const files = [];

	for (const entry of readdirSync(dir)) {
		if (IGNORED_DIRS.has(entry)) continue;

		const path = join(dir, entry);

		if (statSync(path).isDirectory()) files.push(...walk(path));
		else if (/\.(ts|tsx)$/.test(entry)) files.push(path);
	}

	return files;
}

const isTest = (file) => /\.test\.(ts|tsx)$/.test(file);
const isVendored = (file) => VENDORED.some((part) => file.includes(part));
const isStore = (file) => /[\\/]store[\\/](.+[\\/])?store\.ts$/.test(file);
const isActions = (file) => /-actions\.ts$/.test(file);
const isHandle = (file) => /-handle\.tsx?$/.test(file);
const isModal = (file) =>
	/[\\/]features[\\/]modal[\\/]components[\\/]handles[\\/]modal[\\/]modal-handle\.tsx$/.test(
		file,
	);

// #region Stores
const METHOD = /^ {4}(?:async\s+)?(get\s+)?([\w$]+)\s*(?:<[^>]*>)?\(/;
const SETTER_NAME = /^set[A-Z]\w*$/;
const FIELD =
	/^ {4}(?!@|\/\/|static\s|readonly\s|private\s|get\s|constructor\b)[\w$]+\s*[?!]?\s*[:=]/;
const MUTATION =
	/\.(push|pop|shift|unshift|splice|sort|reverse)\(|\bdelete\s+this\b|Object\.assign\(|this\.[\w$]+\s*\[[^\]]+\]\s*=|this\.[\w$]+\.[\w$.]+\s*=/;

function checkStore(file, lines) {
	lines.forEach((line, index) => {
		if (/\bmake(Auto)?Observable\(/.test(line)) {
			report(
				file,
				index + 1,
				"store/decorators",
				"use MobX 7 decorators (@observable accessor, @action, @computed) instead of makeObservable/makeAutoObservable",
			);
		}

		if (
			/@observable(?!\s+accessor\b)/.test(line) &&
			!/@observable\s*$/.test(line)
		) {
			report(
				file,
				index + 1,
				"store/decorators",
				"observable fields need the accessor keyword: @observable accessor field = value",
			);
		}

		if (FIELD.test(line)) {
			report(
				file,
				index + 1,
				"store/decorators",
				"state field without @observable accessor",
			);
		}
	});

	for (let index = 0; index < lines.length; index++) {
		const match = METHOD.exec(lines[index]);

		if (!match) continue;

		const [, getter, name] = match;
		const line = index + 1;

		if (name === "constructor") continue;

		const decorator = lines[index - 1]?.trim() ?? "";

		if (getter) {
			if (decorator !== "@computed") {
				report(
					file,
					line,
					"store/decorators",
					`derived value "${name}" needs @computed`,
				);
			}

			if (!name.startsWith("$")) {
				report(
					file,
					line,
					"store/derived-prefix",
					`derived value "${name}" must start with $`,
				);
			}
			continue;
		}

		if (!SETTER_NAME.test(name)) {
			report(
				file,
				line,
				"store/only-setters",
				`"${name}" is not a plain setter; move this logic to a Handle and call set<Primitive>(value)`,
			);
			continue;
		}

		if (decorator !== "@action") {
			report(file, line, "store/decorators", `setter "${name}" needs @action`);
		}

		const body = [];

		for (let cursor = index + 1; cursor < lines.length; cursor++) {
			if (/^ {4}\}/.test(lines[cursor])) break;
			if (lines[cursor].trim()) body.push(lines[cursor].trim());
		}

		const isPlainAssignment =
			body.length === 1 && /^this\.[\w$]+\s*=\s*[^;]+;$/.test(body[0]);

		if (!isPlainAssignment || MUTATION.test(body.join("\n"))) {
			report(
				file,
				line,
				"store/plain-setter",
				`setter "${name}" must be a single "this.<primitive> = value;" assignment`,
			);
		}
	}
}
// #endregion

// #region Actions
const domainsByFile = new Map();

function checkActions(file, source, lines) {
	for (const match of source.matchAll(/declare module "([^"]+)"/g)) {
		if (match[1] !== "#/lib/command/global") {
			report(
				file,
				lineOf(source, match.index),
				"actions/global-only",
				`augments "${match[1]}"; declare the domain directly on Actions in #/lib/command/global`,
			);
		}
	}

	if (/export\s+interface\s+\w+Actions\b/.test(source)) {
		report(
			file,
			1,
			"actions/flat-domains",
			"helper Actions interfaces are not allowed; declare a flat domain on Actions",
		);
	}

	const start = lines.findIndex((line) => /interface Actions \{/.test(line));

	if (start === -1) return;

	const baseIndent = lines[start].search(/\S/);
	const domainIndent = baseIndent + 4;
	const actionIndent = baseIndent + 8;
	const domains = [];

	for (let index = start + 1; index < lines.length; index++) {
		const line = lines[index];
		const indent = line.search(/\S/);

		if (indent === baseIndent && line.trim().startsWith("}")) break;

		const key = /^\s*([\w$]+)\s*:\s*(.*)$/.exec(line);

		if (!key) continue;

		if (indent === domainIndent)
			domains.push({ name: key[1], line: index + 1 });

		if (indent === actionIndent && key[2].startsWith("{")) {
			report(
				file,
				index + 1,
				"actions/flat-domains",
				`"${key[1]}" nests a third level; action paths must be <domain>.<verb>`,
			);
		}
	}

	domainsByFile.set(file, domains);
}

function checkDuplicatedDomains() {
	const owners = new Map();

	for (const [file, domains] of domainsByFile) {
		for (const domain of domains) {
			const previous = owners.get(domain.name);

			if (previous) {
				report(
					file,
					domain.line,
					"actions/one-file-per-domain",
					`domain "${domain.name}" is already declared in ${relative(process.cwd(), previous)}`,
				);
			} else {
				owners.set(domain.name, file);
			}
		}
	}
}
// #endregion

// #region Handles, dialogs and components
function checkHandle(file, source) {
	for (const match of source.matchAll(/command\.handle\(\s*"([^"]+)"/g)) {
		if (match[1].split(".").length !== 2) {
			report(
				file,
				lineOf(source, match.index),
				"actions/flat-domains",
				`"${match[1]}" must be <domain>.<verb>`,
			);
		}
	}
}

function checkDialogs(file, source) {
	if (isModal(file)) return;

	for (const match of source.matchAll(/<(Dialog|AlertDialog)\.Root\b/g)) {
		report(
			file,
			lineOf(source, match.index),
			"modal/single-app-modal",
			`${match[1]}.Root outside the ModalHandle; send the content with actions.modal.open(Content)`,
		);
	}
}

function checkComponent(file, source) {
	for (const match of source.matchAll(/\b(useMemo|useState)\(/g)) {
		report(
			file,
			lineOf(source, match.index),
			"component/no-local-state",
			`${match[1]} in a component; state and derived values belong to the store`,
		);
	}
}
// #endregion

function lineOf(source, offset) {
	return source.slice(0, offset).split("\n").length;
}

for (const file of walk(root)) {
	if (isTest(file) || isVendored(file)) continue;

	const source = readFileSync(file, "utf8");
	const lines = source.split("\n");

	if (isStore(file)) checkStore(file, lines);
	if (isActions(file)) checkActions(file, source, lines);
	if (isHandle(file)) checkHandle(file, source);
	if (file.endsWith(".tsx")) checkDialogs(file, source);
	if (file.endsWith(".tsx") && !isHandle(file)) checkComponent(file, source);
}

checkDuplicatedDomains();

for (const violation of violations) {
	console.log(
		`${violation.file}:${violation.line}  ${violation.rule}  ${violation.message}`,
	);
}

console.log(
	violations.length === 0
		? "check-architecture: no violations"
		: `check-architecture: ${violations.length} violation(s)`,
);

process.exit(violations.length === 0 ? 0 : 1);
