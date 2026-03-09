use anyhow::Result;
use crate::Mux;
use crate::pane::{Pane, CachePolicy};
use config;
use portable_pty::CommandBuilder;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Arc;

#[derive(Serialize, Deserialize)]
pub struct SessionSnapshot {
    pub version: u32,
    pub windows: Vec<WindowSnapshot>,
}

#[derive(Serialize, Deserialize)]
pub struct WindowSnapshot {
    pub workspace: String,
    pub tabs: Vec<TabSnapshot>,
    pub active_idx: usize,
}

#[derive(Serialize, Deserialize)]
pub struct TabSnapshot {
    pub title: String,
    pub layout: LayoutNode,
    pub active_pane_index: usize,
}

#[derive(Serialize, Deserialize)]
pub enum LayoutNode {
    Leaf(PaneSnapshot),
    Split {
        direction: SplitDirection,
        first: Box<LayoutNode>,
        second: Box<LayoutNode>,
    },
}

#[derive(Serialize, Deserialize)]
pub enum SplitDirection {
    Horizontal,
    Vertical,
}

#[derive(Serialize, Deserialize)]
pub struct PaneSnapshot {
    pub cwd: Option<String>,
    pub command: CommandInfo,
    pub environ: HashMap<String, String>,
}

#[derive(Serialize, Deserialize)]
pub struct CommandInfo {
    pub ai_analyzed: Vec<String>,
}

impl SessionSnapshot {
    pub fn capture() -> Result<Self> {
        let mux = Mux::get();

        // Merge all tabs from all windows into a single window
        let mut all_tabs = Vec::new();
        let mut workspace = String::from("default");

        for window_id in mux.iter_windows() {
            if let Some(window) = mux.get_window(window_id) {
                log::info!("Capturing window {} with {} tabs", window_id, window.len());
                workspace = window.get_workspace().to_string();

                for tab in window.iter() {
                    log::info!("Capturing tab: {}", tab.get_title());
                    all_tabs.push(TabSnapshot::from_tab(&tab)?);
                }
            }
        }

        log::info!("Captured {} tabs total from all windows", all_tabs.len());

        let windows = if !all_tabs.is_empty() {
            vec![WindowSnapshot {
                workspace,
                tabs: all_tabs,
                active_idx: 0,
            }]
        } else {
            vec![]
        };

        Ok(SessionSnapshot { version: 1, windows })
    }

    pub fn load_from_file(path: &Path) -> Result<Option<Self>> {
        if !path.exists() {
            return Ok(None);
        }
        let json = std::fs::read_to_string(path)?;
        if json.trim().is_empty() {
            return Ok(None);
        }
        Ok(Some(serde_json::from_str(&json)?))
    }

    pub fn save_to_file(path: &Path, snapshot: &Self) -> Result<()> {
        let json = serde_json::to_string_pretty(snapshot)?;
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::write(path, json)?;
        Ok(())
    }

    pub async fn restore(&self) -> Result<()> {
        let mux = Mux::get();

        for window_snap in &self.windows {
            window_snap.restore(&mux).await?;
        }
        Ok(())
    }
}

impl WindowSnapshot {
    fn from_window(window: &crate::window::Window) -> Result<Self> {
        let mut tabs = Vec::new();
        log::info!("Capturing window with {} tabs", window.len());
        for tab in window.iter() {
            log::info!("Capturing tab: {}", tab.get_title());
            tabs.push(TabSnapshot::from_tab(&tab)?);
        }
        log::info!("Captured {} tabs total", tabs.len());

        Ok(WindowSnapshot {
            workspace: window.get_workspace().to_string(),
            tabs,
            active_idx: window.get_active_idx(),
        })
    }

    async fn restore(&self, mux: &Arc<Mux>) -> Result<()> {
        if self.tabs.is_empty() {
            return Ok(());
        }

        let domain = mux.default_domain();

        log::info!("Restoring {} tabs", self.tabs.len());

        // Let first tab create the window, then add remaining tabs to it
        if let Some(first_tab) = self.tabs.first() {
            let (_tab, window_id) = first_tab.restore_and_get_tab(mux, &domain).await?;

            // Restore remaining tabs in the same window
            for (idx, tab_snap) in self.tabs.iter().skip(1).enumerate() {
                log::info!("Restoring tab {}", idx + 1);
                tab_snap.restore_in_window(mux, &domain, window_id).await?;
            }
        }

        Ok(())
    }
}

impl TabSnapshot {
    fn from_tab(tab: &Arc<crate::tab::Tab>) -> Result<Self> {
        let pane_tree = tab.codec_pane_tree();
        let positioned = tab.iter_panes_ignoring_zoom();

        // Build a map from pane_id to Pane for quick lookup
        let mut pane_map: HashMap<crate::pane::PaneId, Arc<dyn Pane>> = HashMap::new();
        for pos in &positioned {
            pane_map.insert(pos.pane.pane_id(), Arc::clone(&pos.pane));
        }

        let active_idx = positioned.iter()
            .position(|p| p.is_active)
            .unwrap_or(0);

        let layout = Self::convert_pane_node_to_layout(&pane_tree, &pane_map)?;

        Ok(TabSnapshot {
            title: tab.get_title(),
            layout,
            active_pane_index: active_idx,
        })
    }

    fn convert_pane_node_to_layout(node: &crate::tab::PaneNode, pane_map: &HashMap<crate::pane::PaneId, Arc<dyn Pane>>) -> Result<LayoutNode> {
        match node {
            crate::tab::PaneNode::Empty => {
                // Fallback for empty node
                Ok(LayoutNode::Leaf(PaneSnapshot {
                    cwd: None,
                    command: CommandInfo {
                        ai_analyzed: vec![],
                    },
                    environ: HashMap::new(),
                }))
            }
            crate::tab::PaneNode::Leaf(entry) => {
                if let Some(pane) = pane_map.get(&entry.pane_id) {
                    Ok(LayoutNode::Leaf(PaneSnapshot::from_pane(pane)?))
                } else {
                    // Fallback if pane not found
                    Ok(LayoutNode::Leaf(PaneSnapshot {
                        cwd: None,
                        command: CommandInfo {
                            ai_analyzed: vec![],
                        },
                        environ: HashMap::new(),
                    }))
                }
            }
            crate::tab::PaneNode::Split { left, right, node } => {
                let direction = match node.direction {
                    crate::tab::SplitDirection::Horizontal => SplitDirection::Horizontal,
                    crate::tab::SplitDirection::Vertical => SplitDirection::Vertical,
                };

                Ok(LayoutNode::Split {
                    direction,
                    first: Box::new(Self::convert_pane_node_to_layout(left, pane_map)?),
                    second: Box::new(Self::convert_pane_node_to_layout(right, pane_map)?),
                })
            }
        }
    }

    async fn restore_in_window(&self, mux: &Arc<Mux>, domain: &Arc<dyn crate::domain::Domain>, window_id: crate::window::WindowId) -> Result<()> {
        // Create tab (may create in a new window)
        let tab = self.layout.restore_and_get_tab(mux, domain, window_id).await?;

        // Check if tab is in the correct window
        if let Some(tab_window_id) = mux.window_containing_tab(tab.tab_id()) {
            if tab_window_id != window_id {
                // Tab was created in wrong window, move it to correct window
                log::info!("Moving tab from window {} to window {}", tab_window_id, window_id);
                mux.add_tab_to_window(&tab, window_id)?;

                // Remove tab from old window and delete if empty
                if let Some(mut old_window) = mux.get_window_mut(tab_window_id) {
                    old_window.remove_by_id(tab.tab_id());
                    if old_window.is_empty() {
                        drop(old_window);
                        mux.remove_window_internal(tab_window_id);
                    }
                }
            }
        }

        Ok(())
    }

    async fn restore_and_get_tab(&self, mux: &Arc<Mux>, domain: &Arc<dyn crate::domain::Domain>) -> Result<(Arc<crate::tab::Tab>, crate::window::WindowId)> {
        let window_id = mux.new_empty_window(None, None);
        let tab = self.layout.restore_and_get_tab(mux, domain, *window_id).await?;
        Ok((tab, *window_id))
    }
}

impl LayoutNode {
    async fn restore(&self, mux: &Arc<Mux>, domain: &Arc<dyn crate::domain::Domain>, window_id: crate::window::WindowId) -> Result<()> {
        match self {
            LayoutNode::Leaf(pane) => {
                pane.spawn_and_get_tab(mux, domain, window_id).await?;
                Ok(())
            }
            LayoutNode::Split { direction, first, second } => {
                // Create first pane (this creates the tab)
                let tab = first.restore_and_get_tab(mux, domain, window_id).await?;
                let tab_id = tab.tab_id();
                let first_pane_id = tab.get_active_pane().map(|p| p.pane_id());

                // Create second pane as split
                if let Some(source_pane_id) = first_pane_id {
                    second.restore_as_split(mux, domain, tab_id, source_pane_id, direction).await?;
                }

                Ok(())
            }
        }
    }

    async fn restore_and_get_tab(&self, mux: &Arc<Mux>, domain: &Arc<dyn crate::domain::Domain>, window_id: crate::window::WindowId) -> Result<Arc<crate::tab::Tab>> {
        match self {
            LayoutNode::Leaf(pane) => {
                pane.spawn_and_get_tab(mux, domain, window_id).await
            }
            LayoutNode::Split { direction, first, second } => {
                let tab = Box::pin(first.restore_and_get_tab(mux, domain, window_id)).await?;
                let tab_id = tab.tab_id();
                let first_pane_id = tab.get_active_pane().map(|p| p.pane_id());

                if let Some(source_pane_id) = first_pane_id {
                    Box::pin(second.restore_as_split(mux, domain, tab_id, source_pane_id, direction)).await?;
                }

                Ok(tab)
            }
        }
    }

    async fn restore_as_split(&self, mux: &Arc<Mux>, domain: &Arc<dyn crate::domain::Domain>, tab_id: crate::tab::TabId, source_pane_id: crate::pane::PaneId, parent_direction: &SplitDirection) -> Result<()> {
        match self {
            LayoutNode::Leaf(pane) => {
                pane.spawn_as_split_with_direction(mux, domain, tab_id, source_pane_id, parent_direction).await
            }
            LayoutNode::Split { direction, first, second } => {
                // Create first child as split
                let new_pane_id = Box::pin(first.restore_as_split_and_get_pane(mux, domain, tab_id, source_pane_id, parent_direction)).await?;

                // Create second child as split from the newly created pane
                Box::pin(second.restore_as_split(mux, domain, tab_id, new_pane_id, direction)).await
            }
        }
    }

    async fn restore_as_split_and_get_pane(&self, mux: &Arc<Mux>, domain: &Arc<dyn crate::domain::Domain>, tab_id: crate::tab::TabId, source_pane_id: crate::pane::PaneId, parent_direction: &SplitDirection) -> Result<crate::pane::PaneId> {
        match self {
            LayoutNode::Leaf(pane) => {
                pane.spawn_as_split_with_direction_and_get_pane(mux, domain, tab_id, source_pane_id, parent_direction).await
            }
            LayoutNode::Split { direction, first, second } => {
                let new_pane_id = Box::pin(first.restore_as_split_and_get_pane(mux, domain, tab_id, source_pane_id, parent_direction)).await?;
                Box::pin(second.restore_as_split(mux, domain, tab_id, new_pane_id, direction)).await?;
                Ok(new_pane_id)
            }
        }
    }
}

impl PaneSnapshot {
    fn build_command(&self) -> CommandBuilder {
        let mut cmd = if !self.command.ai_analyzed.is_empty() {
            let mut builder = CommandBuilder::new(&self.command.ai_analyzed[0]);
            if self.command.ai_analyzed.len() > 1 {
                builder.args(&self.command.ai_analyzed[1..]);
            }
            builder
        } else {
            CommandBuilder::new_default_prog()
        };

        if let Some(cwd) = &self.cwd {
            cmd.cwd(PathBuf::from(cwd));
        }

        cmd
    }

    fn from_pane(pane: &Arc<dyn Pane>) -> Result<Self> {
        let cwd = pane.get_current_working_dir(CachePolicy::AllowStale)
            .and_then(|u| u.to_file_path().ok())
            .map(|p| p.to_string_lossy().to_string());

        Ok(PaneSnapshot {
            cwd,
            command: CommandInfo {
                ai_analyzed: vec![],
            },
            environ: HashMap::new(),
        })
    }

    async fn spawn_and_get_tab(&self, mux: &Arc<Mux>, domain: &Arc<dyn crate::domain::Domain>, window_id: crate::window::WindowId) -> Result<Arc<crate::tab::Tab>> {
        let cmd = self.build_command();

        let size = wezterm_term::TerminalSize {
            rows: 24,
            cols: 80,
            pixel_width: 0,
            pixel_height: 0,
            dpi: 0,
        };

        let tab = domain.spawn(
            mux,
            size,
            Some(cmd),
            self.cwd.clone(),
            config::keyassignment::PaneEncoding::default(),
            window_id,
        ).await?;

        Ok(tab)
    }

    async fn spawn_as_split(&self, mux: &Arc<Mux>, domain: &Arc<dyn crate::domain::Domain>, tab_id: crate::tab::TabId, source_pane_id: crate::pane::PaneId) -> Result<()> {
        self.spawn_as_split_with_direction(mux, domain, tab_id, source_pane_id, &SplitDirection::Horizontal).await
    }

    async fn spawn_as_split_with_direction(&self, mux: &Arc<Mux>, domain: &Arc<dyn crate::domain::Domain>, tab_id: crate::tab::TabId, source_pane_id: crate::pane::PaneId, direction: &SplitDirection) -> Result<()> {
        let cmd = self.build_command();

        let split_direction = match direction {
            SplitDirection::Horizontal => crate::tab::SplitDirection::Horizontal,
            SplitDirection::Vertical => crate::tab::SplitDirection::Vertical,
        };

        let split_request = crate::tab::SplitRequest {
            direction: split_direction,
            target_is_second: true,
            top_level: false,
            size: crate::tab::SplitSize::Percent(50),
        };

        let source = crate::domain::SplitSource::Spawn {
            command: Some(cmd),
            command_dir: self.cwd.clone(),
        };

        domain.split_pane(mux, source, tab_id, source_pane_id, split_request).await?;

        Ok(())
    }

    async fn spawn_as_split_with_direction_and_get_pane(&self, mux: &Arc<Mux>, domain: &Arc<dyn crate::domain::Domain>, tab_id: crate::tab::TabId, source_pane_id: crate::pane::PaneId, direction: &SplitDirection) -> Result<crate::pane::PaneId> {
        let cmd = self.build_command();

        let split_direction = match direction {
            SplitDirection::Horizontal => crate::tab::SplitDirection::Horizontal,
            SplitDirection::Vertical => crate::tab::SplitDirection::Vertical,
        };

        let split_request = crate::tab::SplitRequest {
            direction: split_direction,
            target_is_second: true,
            top_level: false,
            size: crate::tab::SplitSize::Percent(50),
        };

        let source = crate::domain::SplitSource::Spawn {
            command: Some(cmd),
            command_dir: self.cwd.clone(),
        };

        let pane = domain.split_pane(mux, source, tab_id, source_pane_id, split_request).await?;

        Ok(pane.pane_id())
    }

    async fn spawn_in_window(&self, mux: &Arc<Mux>, domain: &Arc<dyn crate::domain::Domain>, window_id: crate::window::WindowId) -> Result<()> {
        let cmd = self.build_command();

        let size = wezterm_term::TerminalSize {
            rows: 24,
            cols: 80,
            pixel_width: 0,
            pixel_height: 0,
            dpi: 0,
        };

        let _tab = domain.spawn(
            mux,
            size,
            Some(cmd),
            self.cwd.clone(),
            config::keyassignment::PaneEncoding::default(),
            window_id,
        ).await?;

        Ok(())
    }

    async fn spawn_in_new_window(&self, mux: &Arc<Mux>, workspace: &str) -> Result<()> {
        let domain = mux.default_domain();
        let cmd = self.build_command();

        let window_id = mux.new_empty_window(Some(workspace.to_string()), None);
        let size = wezterm_term::TerminalSize {
            rows: 24,
            cols: 80,
            pixel_width: 0,
            pixel_height: 0,
            dpi: 0,
        };

        let _tab = domain.spawn(
            mux,
            size,
            Some(cmd),
            self.cwd.clone(),
            config::keyassignment::PaneEncoding::default(),
            *window_id,
        ).await?;

        Ok(())
    }
}
