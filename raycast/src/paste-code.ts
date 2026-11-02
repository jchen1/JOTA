import { Clipboard, LaunchType, closeMainWindow, launchCommand, showHUD } from "@raycast/api";
import { showFailureToast } from "@raycast/utils";
import { currentCode, frontmostBrowserURL, listCodes } from "./jota";

export default async function Command() {
  await closeMainWindow();
  const url = await frontmostBrowserURL();

  try {
    const entries = await listCodes(url);
    const confident = entries.filter((entry) => entry.confident);
    const code = confident.length === 1 ? currentCode(confident[0]).code : undefined;
    if (code) {
      await Clipboard.paste(code);
      await showHUD(`Pasted ${confident[0].label || "code"}`);
      return;
    }
    await launchCommand({ name: "search-codes", type: LaunchType.UserInitiated, context: { url } });
  } catch (error) {
    await showFailureToast(error, { title: "Couldn't get a code from JOTA" });
  }
}
