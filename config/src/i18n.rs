use lazy_static::lazy_static;
use parking_lot::RwLock;
use std::borrow::Cow;
use std::collections::HashMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Language {
    En,
    Zh,
}

impl Language {
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "zh" | "chinese" | "中文" => Language::Zh,
            _ => Language::En,
        }
    }

    pub fn as_config_str(&self) -> &'static str {
        match self {
            Language::En => "en",
            Language::Zh => "zh",
        }
    }
}

lazy_static! {
    static ref LANGUAGE: RwLock<Language> = RwLock::new(Language::En);
    static ref ZH_MAP: HashMap<&'static str, &'static str> = build_zh();
}

pub fn set_language(lang: Language) {
    *LANGUAGE.write() = lang;
}

pub fn get_language() -> Language {
    *LANGUAGE.read()
}

pub fn t(key: &'static str) -> Cow<'static, str> {
    if *LANGUAGE.read() == Language::En {
        return Cow::Borrowed(key);
    }
    ZH_MAP
        .get(key)
        .map(|&v| Cow::Borrowed(v))
        .unwrap_or(Cow::Borrowed(key))
}

pub fn t_display(key: &str) -> String {
    if *LANGUAGE.read() == Language::En {
        return key.to_string();
    }
    ZH_MAP
        .get(key)
        .map(|v| v.to_string())
        .unwrap_or_else(|| key.to_string())
}

fn build_zh() -> HashMap<&'static str, &'static str> {
    let mut m = HashMap::new();

    // ── Settings TUI: field labels ──
    m.insert("Theme", "主题");
    m.insert("Font", "字体");
    m.insert("Font Size", "字号");
    m.insert("Line Height", "行高");
    m.insert("Global Hotkey", "全局热键");
    m.insert("Kaku Assistant", "Kaku 助手");
    m.insert("Tab Bar Position", "标签栏位置");
    m.insert("Copy on Select", "选中复制");
    m.insert("Shadow", "阴影");
    m.insert("Bell Tab Indicator", "响铃标签指示");
    m.insert("Bell Dock Badge", "响铃 Dock 角标");
    m.insert("Language", "语言");

    // ── Settings TUI: chrome ──
    m.insert("Settings", "设置");
    m.insert("save and apply changes", "保存并应用更改");
    m.insert("open full config", "打开完整配置");
    m.insert(" Select: ", " 选择：");
    m.insert(" Edit: ", " 编辑：");
    m.insert(": Save  ", "：保存  ");
    m.insert(": Cancel ", "：取消 ");

    // ── Settings TUI: option display values ──
    m.insert("On", "开");
    m.insert("Off", "关");
    m.insert("Bottom", "底部");
    m.insert("Top", "顶部");
    m.insert("English", "English");
    m.insert("中文", "中文");

    // ── macOS menu titles ──
    m.insert("Edit", "编辑");
    m.insert("View", "视图");
    m.insert("Window", "窗口");
    m.insert("Help", "帮助");

    // ── macOS menu items ──
    m.insert("Settings...", "设置...");
    m.insert("Check for Updates...", "检查更新...");
    m.insert("Set as Default Terminal", "设为默认终端");
    m.insert("Services", "服务");

    // ── Command palette: commands ──
    m.insert("Paste primary selection", "粘贴主选区");
    m.insert("Copy to primary selection", "复制到主选区");
    m.insert("Copy to clipboard", "复制到剪贴板");
    m.insert(
        "Copy to clipboard and primary selection",
        "复制到剪贴板和主选区",
    );
    m.insert("Paste from clipboard", "从剪贴板粘贴");
    m.insert("Toggle Full Screen", "切换全屏");
    m.insert("Always on Top", "窗口置顶");
    m.insert("Always on Bottom", "窗口置底");
    m.insert("Normal", "正常");
    m.insert("Minimize", "最小化");
    m.insert("Show/Restore Window", "显示/恢复窗口");
    m.insert("Hide Kaku", "隐藏 Kaku");
    m.insert("New Window", "新建窗口");
    m.insert("Clear Scrollback", "清除回滚缓冲");
    m.insert("Clear the scrollback and viewport", "清除回滚缓冲和视口");
    m.insert("Search", "搜索");
    m.insert("Search pane output", "搜索面板输出");
    m.insert("Kaku Doctor", "Kaku 诊断");
    m.insert(
        "Prompt the user to choose from a list",
        "提示用户从列表中选择",
    );
    m.insert("Prompt the user for confirmation", "提示用户确认");
    m.insert(
        "Prompt the user for a line of text",
        "提示用户输入文本",
    );
    m.insert("QuickSelect", "快速选择");
    m.insert("Enter QuickSelect mode", "进入快速选择模式");
    m.insert(
        "Enter Emoji / Character selection mode",
        "进入表情/字符选择模式",
    );
    m.insert("Select Pane", "选择面板");
    m.insert("Swap a pane with the active pane", "与活动面板交换");
    m.insert(
        "Swap a pane with the active pane, keeping focus",
        "与活动面板交换（保持焦点）",
    );
    m.insert("Move Pane to New Tab", "移动面板到新标签页");
    m.insert("Move Pane to New Window", "移动面板到新窗口");
    m.insert("Decrease Font Size", "减小字号");
    m.insert("Increase Font Size", "增大字号");
    m.insert("Reset Font Size", "重置字号");
    m.insert("Reset Window & Font Size", "重置窗口和字号");
    m.insert("New Tab", "新建标签页");
    m.insert("Close Tab", "关闭标签页");
    m.insert("Close Pane", "关闭面板");
    m.insert("Close current Pane", "关闭当前面板");
    m.insert("Reopen Last Closed Tab", "重新打开上次关闭的标签页");
    m.insert("Previous Window", "上一个窗口");
    m.insert("Next Window", "下一个窗口");
    m.insert("Previous Window (No Wrap)", "上一个窗口（不循环）");
    m.insert("Next Window (No Wrap)", "下一个窗口（不循环）");
    m.insert("Previous Tab", "上一个标签页");
    m.insert("Next Tab", "下一个标签页");
    m.insert(
        "Reload configuration (disabled)",
        "重新加载配置（已禁用）",
    );
    m.insert("Quit Kaku", "退出 Kaku");
    m.insert("Move Tab Left", "向左移动标签页");
    m.insert("Move Tab Right", "向右移动标签页");
    m.insert("Scroll Up One Page", "向上翻一页");
    m.insert("Scroll Down One Page", "向下翻一页");
    m.insert("Scroll to Bottom", "滚动到底部");
    m.insert("Scroll to Top", "滚动到顶部");
    m.insert("Activate Copy Mode", "激活复制模式");
    m.insert("Split Pane Top/Bottom", "上下分割面板");
    m.insert("Split Pane Left/Right", "左右分割面板");
    m.insert("Resize Split Left", "向左调整分割线");
    m.insert("Resize Split Right", "向右调整分割线");
    m.insert("Resize Split Up", "向上调整分割线");
    m.insert("Resize Split Down", "向下调整分割线");
    m.insert("Activate Pane Left", "激活左侧面板");
    m.insert("Activate Pane Right", "激活右侧面板");
    m.insert("Activate Pane Up", "激活上方面板");
    m.insert("Activate Pane Down", "激活下方面板");
    m.insert("Zoom Pane", "面板缩放");
    m.insert("Last Active Tab", "上一个活动标签页");
    m.insert("Clear the key table stack", "清除按键表栈");
    m.insert("Open link at mouse cursor", "打开鼠标处链接");
    m.insert("Launcher", "启动器");
    m.insert("Tab Navigator", "标签页导航");
    m.insert("AI Config", "AI 配置");
    m.insert("Yazi File Manager", "Yazi 文件管理器");
    m.insert("Remote Files", "远程文件");
    m.insert("Star on GitHub", "GitHub 加星");
    m.insert("Discuss on GitHub", "GitHub 讨论");
    m.insert("Report Issue", "报告问题");
    m.insert("Does nothing", "无操作");
    m.insert("Command Palette", "命令面板");
    m.insert("Toggle Split Direction", "切换分割方向");
    m.insert(
        "Detach the domain of the active pane",
        "断开活动面板的域",
    );
    m.insert("Detach the default domain", "断开默认域");
    m.insert("Pop the current key table", "弹出当前按键表");
    m.insert("Activate right-most tab", "激活最右标签页");
    m.insert(
        "Reset the terminal emulation state in the current pane",
        "重置当前面板的终端仿真状态",
    );

    // ── Launcher overlay ──
    m.insert("Pane Encoding", "面板编码");
    m.insert("(default shell)", "（默认 Shell）");
    m.insert("Attach", "连接");
    m.insert("Switch to workspace", "切换工作区");
    m.insert("Create new Workspace", "创建新工作区");
    m.insert("current is", "当前为");
    m.insert("panes", "个面板");
    m.insert("Set pane encoding to", "设置面板编码为");
    m.insert(
        "Select encoding  |  Enter = set  |  Esc = back  |  / = filter",
        "选择编码  |  Enter = 设置  |  Esc = 返回  |  / = 筛选",
    );
    m.insert("domain", "域");

    // ── Commands: dynamic format parts ──
    m.insert("Attach Domain", "连接域");
    m.insert("Detach Domain", "断开域");
    m.insert("Domain", "域");
    m.insert("Lazygit", "Lazygit");
    m.insert(
        "Activate the tab to the left (no wrapping)",
        "向左激活标签页（不循环）",
    );
    m.insert(
        "Activate the tab to the right (no wrapping)",
        "向右激活标签页（不循环）",
    );

    m
}
