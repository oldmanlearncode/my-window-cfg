local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-----------------------------------------------------------
-- Default shell: Ubuntu WSL
-----------------------------------------------------------

--config.default_prog = {
--  'wsl.exe',
--  '-d',
--  'Ubuntu-24.04',
--  '--cd',
--  '~',
--}

-----------------------------------------------------------
-- Appearance
-----------------------------------------------------------

config.color_scheme = 'Catppuccin Mocha'

config.font = wezterm.font_with_fallback {
  'JetBrainsMono Nerd Font',
  'JetBrains Mono',
  'Segoe UI Emoji',
}

config.font_size = 12.5
config.line_height = 1.05

config.window_padding = {
  left = 12,
  right = 12,
  top = 8,
  bottom = 8,
}

config.window_background_opacity = 0.94

config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.integrated_title_button_alignment = 'Right'

config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_max_width = 28

config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 600

config.initial_cols = 120
config.initial_rows = 32

config.scrollback_lines = 10000
config.audible_bell = 'Disabled'

-----------------------------------------------------------
-- Windows blur
-----------------------------------------------------------

-- Nếu thích hiệu ứng Windows Mica/Acrylic có thể thử:
-- config.window_background_opacity = 0.0
-- config.win32_system_backdrop = 'Mica'

-----------------------------------------------------------
-- Leader key
--
-- Ctrl+A rồi nhấn command
-----------------------------------------------------------

config.leader = {
  key = 'a',
  mods = 'CTRL',
  timeout_milliseconds = 1500,
}

-----------------------------------------------------------
-- Key bindings
-----------------------------------------------------------

config.keys = {

  -- Ctrl+A, A -> gửi Ctrl+A thật xuống shell
  {
    key = 'a',
    mods = 'LEADER',
    action = act.SendKey {
      key = 'a',
      mods = 'CTRL',
    },
  },

  ---------------------------------------------------------
  -- Tabs
  ---------------------------------------------------------

  -- Ctrl+A, C -> new tab
  {
    key = 'c',
    mods = 'LEADER',
    action = act.SpawnTab 'CurrentPaneDomain',
  },

  -- Ctrl+A, N -> next tab
  {
    key = 'n',
    mods = 'LEADER',
    action = act.ActivateTabRelative(1),
  },

  -- Ctrl+A, P -> previous tab
  {
    key = 'p',
    mods = 'LEADER',
    action = act.ActivateTabRelative(-1),
  },

  ---------------------------------------------------------
  -- Pane split
  ---------------------------------------------------------

  -- Ctrl+A, \ -> split left/right
  {
    key = '\\',
    mods = 'LEADER',
    action = act.SplitHorizontal {
      domain = 'CurrentPaneDomain',
    },
  },

  -- Ctrl+A, - -> split top/bottom
  {
    key = '-',
    mods = 'LEADER',
    action = act.SplitVertical {
      domain = 'CurrentPaneDomain',
    },
  },

  ---------------------------------------------------------
  -- Pane navigation: vim style
  ---------------------------------------------------------

  {
    key = 'h',
    mods = 'LEADER',
    action = act.ActivatePaneDirection 'Left',
  },

  {
    key = 'j',
    mods = 'LEADER',
    action = act.ActivatePaneDirection 'Down',
  },

  {
    key = 'k',
    mods = 'LEADER',
    action = act.ActivatePaneDirection 'Up',
  },

  {
    key = 'l',
    mods = 'LEADER',
    action = act.ActivatePaneDirection 'Right',
  },

  ---------------------------------------------------------
  -- Pane management
  ---------------------------------------------------------

  -- Ctrl+A, X -> close pane
  {
    key = 'x',
    mods = 'LEADER',
    action = act.CloseCurrentPane {
      confirm = true,
    },
  },

  -- Ctrl+A, Z -> zoom/unzoom pane
  {
    key = 'z',
    mods = 'LEADER',
    action = act.TogglePaneZoomState,
  },

  ---------------------------------------------------------
  -- Search
  ---------------------------------------------------------

  {
    key = 'f',
    mods = 'CTRL|SHIFT',
    action = act.Search {
      CaseInSensitiveString = '',
    },
  },

  ---------------------------------------------------------
  -- Reload config
  ---------------------------------------------------------

  {
    key = 'r',
    mods = 'CTRL|SHIFT',
    action = act.ReloadConfiguration,
  },
  
  ---------------------------------------------------------
  -- Select DOMAINS
  ---------------------------------------------------------  
  {
  key = 'd',
  mods = 'LEADER',
  action = act.ShowLauncherArgs {
    flags = 'FUZZY|DOMAINS|LAUNCH_MENU_ITEMS',
    title = 'Select environment',
  },
},
}

-----------------------------------------------------------
-- Launch menu
-----------------------------------------------------------

config.launch_menu = {
  {
    label = 'PowerShell 7',
    args = { 'pwsh.exe', '-NoLogo' },
  },
  {
    label = 'Windows PowerShell',
    args = { 'powershell.exe', '-NoLogo' },
  },
  {
    label = 'CMD',
    args = { 'cmd.exe' },
  },
}


-- Khi WezTerm vừa attach GUI, hiện launcher chọn domain
wezterm.on('gui-attached', function(domain)
  local mux = wezterm.mux

  for _, mux_window in ipairs(mux.all_windows()) do
    local window = mux_window:gui_window()

    if window then
      local tab = mux_window:active_tab()
      local pane = tab and tab:active_pane()

      if pane then
        window:perform_action(
          act.ShowLauncherArgs {
            flags = 'FUZZY|DOMAINS|LAUNCH_MENU_ITEMS',
            title = 'Select environment',
          },
          pane
        )
      end
    end
  end
end)

return config
