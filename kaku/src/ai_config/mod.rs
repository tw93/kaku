pub mod tui;

use anyhow::Context;
use clap::Parser;

#[derive(Debug, Parser, Clone, Default)]
pub struct AiConfigCommand {}

impl AiConfigCommand {
    pub fn run(&self) -> anyhow::Result<()> {
        tui::run().context("ai config tui")
    }
}
