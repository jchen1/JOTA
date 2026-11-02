import { Clipboard, LaunchType, closeMainWindow, launchCommand, showHUD } from "@raycast/api";
import { showFailureToast } from "@raycast/utils";
import { currentCode, frontmostBrowserURL, listCodes } from "./jota";

export default async function Command() {
  await closeMainWindow();
  const url = await frontmostBrowserURL();

  try {
    const list = await listCodes(url);
    const suggested = list.entries.filter((entry) => entry.suggested);
    if (suggested.length === 1) {
      const entry = suggested[0];
      await Clipboard.paste(currentCode(entry, list.fetchedAt).code);
      await showHUD(`Pasted ${entry.label || "code"}`);
      return;
    }
    await launchCommand({ name: "search-codes", type: LaunchType.UserInitiated, context: { url } });
  } catch (error) {
    await showFailureToast(error, { title: "Couldn't get a code from JOTA" });
  }
}
