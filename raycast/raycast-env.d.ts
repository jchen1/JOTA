/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {
  /** JOTA Helper Path - Path to the JOTAHelper binary inside the JOTA Mac app */
  "helperPath": string
}

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Preferences accessible in the `paste-code` command */
  export type PasteCode = ExtensionPreferences & {}
  /** Preferences accessible in the `search-codes` command */
  export type SearchCodes = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `paste-code` command */
  export type PasteCode = {}
  /** Arguments passed to the `search-codes` command */
  export type SearchCodes = {}
}

