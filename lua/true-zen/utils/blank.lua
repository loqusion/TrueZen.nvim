local M = {}

local colors = require("true-zen.utils.colors")
local data = require("true-zen.utils.data")
local config = require("true-zen.config").options
local lualine = require("true-zen.utils.lualine")

local IGNORED_BUF_TYPES = data.set_of(config.modes.minimalist.ignored_buf_types)

local saved_opts = {}
local saved_highlights = {}

local function is_ignored_buftype(win_handle)
	local buf_handle = vim.api.nvim_win_get_buf(win_handle)
	local buftype = vim.api.nvim_buf_get_option(buf_handle, "buftype")
	return IGNORED_BUF_TYPES[buftype] ~= nil
end

local function get_suitable_window_handle()
	local current_window_handle = 0
	if not is_ignored_buftype(current_window_handle) then
		return current_window_handle
	end

	local windows = vim.api.nvim_tabpage_list_wins(0)
	for _, win_handle in ipairs(windows) do
		if not is_ignored_buftype(win_handle) then
			return win_handle
		end
	end

	return nil
end

local function is_special_opt(opt_name)
	return opt_name == "number" or opt_name == "relativenumber"
end

local function set_opt_for_every_window(name, value)
	local windows = vim.api.nvim_tabpage_list_wins(0)
	for _, win_handle in ipairs(windows) do
		vim.api.nvim_win_set_option(win_handle, name, value)
	end
end

local function set_opts()
	local suitable_window_handle = get_suitable_window_handle()

	for opt_name, opt_value in pairs(config.modes.minimalist.options) do
		local ok, current_opt_value = pcall(vim.api.nvim_win_get_option, suitable_window_handle, opt_name)
		if not ok then
			current_opt_value = vim.api.nvim_get_option(opt_name)
		end
		saved_opts[opt_name] = current_opt_value
		if is_special_opt(opt_name) then
			set_opt_for_every_window(opt_name, opt_value)
		else
			vim.api.nvim_set_option(opt_name, opt_value)
		end
	end
end

local function restore_opts()
	for k, v in pairs(saved_opts) do
		if is_special_opt(k) then
			set_opt_for_every_window(k, v)
		else
			vim.api.nvim_set_option(k, v)
		end
	end
end

local function set_highlights()
	saved_highlights = {
		TabLine = colors.get_hl("TabLine"),
		TabLineFill = colors.get_hl("TabLineFill"),
	}

	local base = colors.get_hl("Normal")["background"] or "NONE"
	for hi_group, _ in pairs(saved_highlights) do
		colors.highlight(hi_group, { bg = base, fg = base }, true)
	end
end

local function restore_highlights()
	for hi_group, props in pairs(saved_highlights) do
		colors.highlight(hi_group, { fg = props.foreground, bg = props.background }, true)
	end
end

function M.on()
	set_highlights()
	set_opts()
	if lualine.is_available() then
		lualine.hide()
	end
end

function M.off()
	restore_highlights()
	restore_opts()
	if lualine.is_available() then
		lualine.show()
	end
end

return M
