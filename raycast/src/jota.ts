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
  /** Unix time (seconds) when `code` expires; `nextCode` is valid for one period after. */
  expiresAt?: number;
  /** Loosely matches the current site; listed first. */
  suggested: boolean;
  /** Matches the current site strongly enough to paste without asking. */
  confident: boolean;
};

export class JOTAError extends Error {}

function helperPath(): string {
  const { helperPath } = getPreferenceValues<{ helperPath?: string }>();
  return (
    helperPath?.trim() ||
    "/Applications/JOTA.app/Contents/Helpers/JOTAHelper.app/Contents/MacOS/JOTAHelper"
  );
}

export function listCodes(url?: string): Promise<CodeEntry[]> {
  const path = helperPath();
  if (!existsSync(path)) {
    return Promise.reject(new JOTAError(`JOTA helper not found at ${path}. Set its path in the extension preferences.`));
  }
  const args = url ? ["list", "--url", url] : ["list"];
  return new Promise((resolve, reject) => {
    execFile(path, args, { timeout: 15_000 }, (error, stdout) => {
      try {
        const parsed = JSON.parse(stdout);
        if (!Array.isArray(parsed)) {
          reject(new JOTAError(parsed?.error ?? "Unexpected output from JOTA helper"));
          return;
        }
        resolve(parsed);
      } catch {
        reject(new JOTAError(error?.message ?? "Couldn't read JOTA helper output"));
      }
    });
  });
}

/** The code valid at `now` (ms), or no code once both fetched periods have passed. */
export function currentCode(entry: CodeEntry, now = Date.now()): { code?: string; secondsLeft?: number } {
  if (entry.period === undefined || entry.expiresAt === undefined) {
    return { code: entry.code };
  }
  const nowSeconds = now / 1000;
  if (nowSeconds < entry.expiresAt) {
    return { code: entry.code, secondsLeft: Math.ceil(entry.expiresAt - nowSeconds) };
  }
  const nextExpiry = entry.expiresAt + entry.period;
  if (entry.nextCode && nowSeconds < nextExpiry) {
    return { code: entry.nextCode, secondsLeft: Math.ceil(nextExpiry - nowSeconds) };
  }
  return {};
}

/** Earliest time (ms) any fetched code expires; refetching then keeps a valid code on hand. */
export function refreshAt(entries: CodeEntry[]): number | undefined {
  const expiries = entries.flatMap((entry) => (entry.expiresAt === undefined ? [] : [entry.expiresAt * 1000]));
  return expiries.length > 0 ? Math.min(...expiries) : undefined;
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
