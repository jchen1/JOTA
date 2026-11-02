import { Action, ActionPanel, Color, Icon, LaunchProps, List } from "@raycast/api";
import { usePromise } from "@raycast/utils";
import { useEffect, useState } from "react";
import { CodeEntry, CodeList, currentCode, frontmostBrowserURL, listCodes } from "./jota";

type Context = { url?: string };

export default function Command(props: LaunchProps<{ launchContext: Context }>) {
  const { data, isLoading, error, revalidate } = usePromise(async (): Promise<CodeList & { url?: string }> => {
    const url = props.launchContext?.url ?? (await frontmostBrowserURL());
    return { ...(await listCodes(url)), url };
  });

  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);

  if (error) {
    return (
      <List>
        <List.EmptyView
          icon={Icon.ExclamationMark}
          title="Couldn't load codes"
          description={error.message}
          actions={
            <ActionPanel>
              <Action title="Try Again" icon={Icon.ArrowClockwise} onAction={revalidate} />
            </ActionPanel>
          }
        />
      </List>
    );
  }

  const suggested = data?.entries.filter((entry) => entry.suggested) ?? [];
  const others = data?.entries.filter((entry) => !entry.suggested) ?? [];
  const host = data?.url ? safeHost(data.url) : undefined;

  const item = (entry: CodeEntry) => {
    const { code, secondsLeft } = currentCode(entry, data!.fetchedAt, now);
    const expiring = secondsLeft !== undefined && secondsLeft <= 5;
    return (
      <List.Item
        key={entry.id}
        title={entry.label || "Untitled"}
        subtitle={entry.user}
        keywords={[entry.user]}
        accessories={[
          { tag: { value: code, color: expiring ? Color.Red : Color.PrimaryText } },
          ...(secondsLeft !== undefined ? [{ text: `${secondsLeft}s` }] : []),
        ]}
        actions={
          <ActionPanel>
            <Action.Paste title="Paste Code" content={code} />
            <Action.CopyToClipboard title="Copy Code" content={code} concealed />
          </ActionPanel>
        }
      />
    );
  };

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search codes">
      {suggested.length > 0 && <List.Section title={host ? `Suggested for ${host}` : "Suggested"}>{suggested.map(item)}</List.Section>}
      <List.Section title={suggested.length > 0 ? "Other Codes" : "All Codes"}>{others.map(item)}</List.Section>
    </List>
  );
}

function safeHost(url: string): string | undefined {
  try {
    return new URL(url).host;
  } catch {
    return undefined;
  }
}
