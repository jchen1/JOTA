import { getFrontmostApplication, getPreferenceValues } from "@raycast/api";
import { runAppleScript } from "@raycast/utils";
import { execFile } from "node:child_process";
import { existsSync } from "node:fs";

export type CodeEntry = {
  id: string;
  label: string;
  user: string;
  code: string;
  nextCode?: string;
  period?: number;
  secondsLeft?: number;
  suggested: boolean;
};

export type CodeList = {
  entries: CodeEntry[];
  /** When the helper produced the list, used to roll codes over locally. */
  fetchedAt: number;
};

export class JOTAError extends Error {}

const LOCKED_EXIT_CODE = 3;

function helperPath(): string {
  const { helperPath } = getPreferenceValues<{ helperPath?: string }>();
  return (
    helperPath?.trim() ||
    "/Applications/JOTA.app/Contents/Helpers/JOTAHelper.app/Contents/MacOS/JOTAHelper"
  );
}

export function listCodes(url?: string): Promise<CodeList> {
  const path = helperPath();
  if (!existsSync(path)) {
    return Promise.reject(new JOTAError(`JOTA helper not found at ${path}. Set its path in the extension preferences.`));
  }
  const args = url ? ["list", "--url", url] : ["list"];
  return new Promise((resolve, reject) => {
    // Generous timeout: the helper may be waiting on Touch ID.
    execFile(path, args, { timeout: 120_000 }, (error, stdout) => {
      const exitCode = error && typeof error.code === "number" ? error.code : 0;
      if (exitCode === LOCKED_EXIT_CODE) {
        reject(new JOTAError("JOTA is locked"));
        return;
      }
      try {
        const parsed = JSON.parse(stdout);
        if (!Array.isArray(parsed)) {
          reject(new JOTAError(parsed?.error ?? "Unexpected output from JOTA helper"));
          return;
        }
        resolve({ entries: parsed, fetchedAt: Date.now() });
      } catch {
        reject(new JOTAError(error?.message ?? "Couldn't read JOTA helper output"));
      }
    });
  });
}

/** The code valid at `now`, using `nextCode` once the period the helper saw has ended. */
export function currentCode(entry: CodeEntry, fetchedAt: number, now = Date.now()): { code: string; secondsLeft?: number } {
  if (entry.period === undefined || entry.secondsLeft === undefined) {
    return { code: entry.code };
  }
  const elapsed = Math.floor((now - fetchedAt) / 1000);
  const left = entry.secondsLeft - elapsed;
  if (left > 0) {
    return { code: entry.code, secondsLeft: left };
  }
  if (entry.nextCode && left > -entry.period) {
    return { code: entry.nextCode, secondsLeft: left + entry.period };
  }
  return { code: "------", secondsLeft: 0 };
}

const chromiumBrowsers: Record<string, string> = {
  "com.google.Chrome": "Google Chrome",
  "com.google.Chrome.beta": "Google Chrome Beta",
  "com.google.Chrome.canary": "Google Chrome Canary",
  "com.brave.Browser": "Brave Browser",
  "com.microsoft.edgemac": "Microsoft Edge",
  "com.vivaldi.Vivaldi": "Vivaldi",
  "company.thebrowser.Browser": "Arc",
};

const safariBrowsers: Record<string, string> = {
  "com.apple.Safari": "Safari",
  "com.apple.SafariTechnologyPreview": "Safari Technology Preview",
};

/** URL of the active tab if the frontmost app is a supported browser. */
export async function frontmostBrowserURL(): Promise<string | undefined> {
  try {
    const app = await getFrontmostApplication();
    const bundleId = app.bundleId ?? "";
    if (chromiumBrowsers[bundleId]) {
      return await runAppleScript(`tell application "${chromiumBrowsers[bundleId]}" to get URL of active tab of front window`);
    }
    if (safariBrowsers[bundleId]) {
      return await runAppleScript(`tell application "${safariBrowsers[bundleId]}" to get URL of front document`);
    }
  } catch {
    // No window, or Automation permission denied: fall back to the full list.
  }
  return undefined;
}
