pub const OPENCODE_THEME_DARK_JSON: &str = r##"{
  "$schema": "https://opencode.ai/theme.json",
  "defs": {
    "bg": "#15141b",
    "panel": "#15141b",
    "element": "#1f1d28",
    "text": "#edecee",
    "muted": "#6d6d6d",
    "primary": "#a277ff",
    "secondary": "#61ffca",
    "accent": "#ffca85",
    "error": "#ff6767",
    "warning": "#ffca85",
    "success": "#61ffca",
    "info": "#5fa8ff",
    "border": "#15141b",
    "border_active": "#29263c",
    "border_subtle": "#15141b"
  },
  "theme": {
    "primary": "primary",
    "secondary": "secondary",
    "accent": "accent",
    "error": "error",
    "warning": "warning",
    "success": "success",
    "info": "info",
    "text": "text",
    "textMuted": "muted",
    "background": "bg",
    "backgroundPanel": "panel",
    "backgroundElement": "element",
    "border": "border",
    "borderActive": "border_active",
    "borderSubtle": "border_subtle",
    "diffAdded": "success",
    "diffRemoved": "error",
    "diffContext": "muted",
    "diffHunkHeader": "primary",
    "diffHighlightAdded": "success",
    "diffHighlightRemoved": "error",
    "diffAddedBg": "#1b2a24",
    "diffRemovedBg": "#2a1b20",
    "diffContextBg": "bg",
    "diffLineNumber": "muted",
    "diffAddedLineNumberBg": "#1b2a24",
    "diffRemovedLineNumberBg": "#2a1b20",
    "markdownText": "text",
    "markdownHeading": "primary",
    "markdownLink": "info",
    "markdownLinkText": "primary",
    "markdownCode": "accent",
    "markdownBlockQuote": "muted",
    "markdownEmph": "accent",
    "markdownStrong": "secondary",
    "markdownHorizontalRule": "muted",
    "markdownListItem": "primary",
    "markdownListEnumeration": "accent",
    "markdownImage": "info",
    "markdownImageText": "primary",
    "markdownCodeBlock": "text",
    "syntaxComment": "muted",
    "syntaxKeyword": "primary",
    "syntaxFunction": "secondary",
    "syntaxVariable": "text",
    "syntaxString": "success",
    "syntaxNumber": "accent",
    "syntaxType": "info",
    "syntaxOperator": "primary",
    "syntaxPunctuation": "text"
  }
}
"##;

pub const OPENCODE_THEME_LIGHT_JSON: &str = r##"{
  "$schema": "https://opencode.ai/theme.json",
  "defs": {
    "bg": "#FFFCF0",
    "panel": "#FFFCF0",
    "element": "#E8E6DB",
    "text": "#100F0F",
    "muted": "#5C5B56",
    "primary": "#5E3DB3",
    "secondary": "#24837B",
    "accent": "#8C6D00",
    "error": "#AF3029",
    "warning": "#8C6D00",
    "success": "#24837B",
    "info": "#205EA6",
    "border": "#D5D3C7",
    "border_active": "#B8B7AD",
    "border_subtle": "#E8E6DB"
  },
  "theme": {
    "primary": "primary",
    "secondary": "secondary",
    "accent": "accent",
    "error": "error",
    "warning": "warning",
    "success": "success",
    "info": "info",
    "text": "text",
    "textMuted": "muted",
    "background": "bg",
    "backgroundPanel": "panel",
    "backgroundElement": "element",
    "border": "border",
    "borderActive": "border_active",
    "borderSubtle": "border_subtle",
    "diffAdded": "success",
    "diffRemoved": "error",
    "diffContext": "muted",
    "diffHunkHeader": "primary",
    "diffHighlightAdded": "success",
    "diffHighlightRemoved": "error",
    "diffAddedBg": "#E6F2E8",
    "diffRemovedBg": "#F5E6E6",
    "diffContextBg": "bg",
    "diffLineNumber": "muted",
    "diffAddedLineNumberBg": "#E6F2E8",
    "diffRemovedLineNumberBg": "#F5E6E6",
    "markdownText": "text",
    "markdownHeading": "primary",
    "markdownLink": "info",
    "markdownLinkText": "primary",
    "markdownCode": "accent",
    "markdownBlockQuote": "muted",
    "markdownEmph": "accent",
    "markdownStrong": "secondary",
    "markdownHorizontalRule": "muted",
    "markdownListItem": "primary",
    "markdownListEnumeration": "accent",
    "markdownImage": "info",
    "markdownImageText": "primary",
    "markdownCodeBlock": "text",
    "syntaxComment": "muted",
    "syntaxKeyword": "primary",
    "syntaxFunction": "secondary",
    "syntaxVariable": "text",
    "syntaxString": "success",
    "syntaxNumber": "accent",
    "syntaxType": "info",
    "syntaxOperator": "primary",
    "syntaxPunctuation": "text"
  }
}
"##;

/// Returns the appropriate OpenCode theme JSON based on user's Kaku theme setting.
pub fn opencode_theme_json() -> &'static str {
    if theme::is_light_theme() {
        OPENCODE_THEME_LIGHT_JSON
    } else {
        OPENCODE_THEME_DARK_JSON
    }
}

pub mod theme;
mod tui;

use anyhow::Context;
use clap::Parser;

#[derive(Debug, Parser, Clone, Default)]
pub struct AiConfigCommand {}

impl AiConfigCommand {
    pub fn run(&self) -> anyhow::Result<()> {
        tui::run().context("ai config tui")
    }
}
