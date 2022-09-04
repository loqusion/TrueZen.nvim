local M = {
	running = false,
}

local colors = require("true-zen.utils.colors")
local data = require("true-zen.utils.data")
local blank = require("true-zen.utils.blank")
local config = require("true-zen.config").options
local global = require("true-zen.global")

local padding = config.modes.ataraxis.padding
local minimum_writing_area = config.modes.ataraxis.minimum_writing_area
local CARDINAL_POINTS = {
	left = "width",
	right = "width",
	top = "height",
	bottom = "height",
}

local base = colors.get_hl("Normal")["background"] or "NONE"

if base ~= "NONE" and config.modes.ataraxis.backdrop ~= 0 then
	if config.modes.ataraxis.shade == "dark" then
		base = colors.darken("#000000", config.modes.ataraxis.backdrop, base)
	else
		base = colors.lighten("#ffffff", config.modes.ataraxis.backdrop, base)
	end

	colors.highlight("TZBackground", { fg = base, bg = base }, true)
end

vim.api.nvim_create_augroup("TrueZenAtaraxis", {
	clear = true,
})

local original_opts = {}
local original_highlights = {}
local win = {}
local opts = {
	bo = {
		buftype = "nofile",
		bufhidden = "hide",
		modifiable = false,
		buflisted = false,
		swapfile = false,
	},
	wo = {
		cursorline = false,
		cursorcolumn = false,
		number = false,
		relativenumber = false,
		foldenable = false,
		list = false,
	},
}

local function save_opts()
	original_opts.fillchars = vim.o.fillchars
	original_highlights = {
		just_bg = {
			MsgArea = colors.get_hl("MsgArea"),
		},
		FoldColumn = colors.get_hl("FoldColumn"),
		ColorColumn = colors.get_hl("ColorColumn"),
		VertSplit = colors.get_hl("VertSplit"),
		SignColumn = colors.get_hl("SignColumn"),
		WinBar = colors.get_hl("WinBar"),
	}
end

local function pad_win(new, props, move)
	vim.cmd(new)

	local win_id = vim.api.nvim_get_current_win()

	if props.width ~= nil then
		vim.api.nvim_win_set_width(0, props.width)
	else
		vim.api.nvim_win_set_height(0, props.height)
	end

	vim.wo.winhighlight = "Normal:TZBackground"

	for opt_type, _ in pairs(opts) do
		for opt, val in pairs(opts[opt_type]) do
			vim[opt_type][opt] = val
		end
	end

	vim.w.tz_pad_win = true

	vim.cmd(move)
	return win_id
end

local function fix_padding(orientation, dimension, mod)
	mod = mod or 0
	local window_dimension = vim.api.nvim_list_uis()[1][dimension] - mod
	local mwa = minimum_writing_area[dimension]

	if mwa >= window_dimension then
		return 1
	else
		local wanted_available_size = (
				dimension == "width" and (padding.left + padding.right) or (padding.top + padding.bottom)
			) + mwa

		if wanted_available_size > window_dimension then
			local available_space = window_dimension - mwa
			return math.floor(available_space / 2)
		else
			return padding[orientation]
		end
	end
end

local function generate_layout()
	local splitbelow, splitright = vim.o.splitbelow, vim.o.splitright
	vim.o.splitbelow, vim.o.splitright = true, true

	local left_padding = fix_padding("left", "width")
	local right_padding = fix_padding("right", "width")
	local top_padding = fix_padding("top", "height")
	local bottom_padding = fix_padding("bottom", "height")

	win.main = vim.api.nvim_get_current_win()

	win.left = pad_win("leftabove vnew", { width = left_padding }, "wincmd l")
	win.right = pad_win("vnew", { width = right_padding }, "wincmd h")
	win.top = pad_win("leftabove new", { height = top_padding }, "wincmd j")
	win.bottom = pad_win("rightbelow new", { height = bottom_padding }, "wincmd k")

	vim.o.splitbelow, vim.o.splitright = splitbelow, splitright
end

local function resize_layout()
	local pad_sizes = {}
	pad_sizes.left = fix_padding("left", "width")
	pad_sizes.right = fix_padding("right", "width")
	pad_sizes.top = fix_padding("top", "height")
	pad_sizes.bottom = fix_padding("bottom", "height")

	for point, dimension in pairs(CARDINAL_POINTS) do
		if vim.api.nvim_win_is_valid(win[point]) then
			if dimension == "width" then
				vim.api.nvim_win_set_width(win[point], pad_sizes[point])
			else
				vim.api.nvim_win_set_height(win[point], pad_sizes[point])
			end
		end
	end
end

function M.on()
	if M.running then
		return
	end

	global.off()
	data.do_callback("ataraxis", "open", "pre")

	local cursor_pos = vim.fn.getpos(".")
	if config.modes.ataraxis.quit_untoggles == true then
		vim.api.nvim_create_autocmd({ "QuitPre" }, {
			callback = function()
				M.off()
			end,
			group = "TrueZenAtaraxis",
		})
	end

	blank.on()
	save_opts()

	if vim.fn.filereadable(vim.fn.expand("%:p")) == 1 then
		vim.cmd("tabedit %")
	end

	generate_layout()

	vim.o.fillchars = "stl: ,stlnc: ,vert: ,diff: ,msgsep: ,eob: "

	for hi_group, _ in pairs(original_highlights) do
		if hi_group == "just_bg" then
			for bg_hi_group, _ in pairs(original_highlights["just_bg"]) do
				colors.highlight(bg_hi_group, { bg = base })
			end
		else
			colors.highlight(hi_group, { bg = base, fg = base })
		end
	end

	for integration, val in pairs(config.integrations) do
		if (type(val) == "table" and val.enabled or val) == true and integration ~= "tmux" then
			require("true-zen.integrations." .. integration).on()
		end
	end

	vim.api.nvim_create_autocmd({ "VimResized" }, {
		callback = function()
			resize_layout()
		end,
		group = "TrueZenAtaraxis",
		desc = "Resize TrueZen pad windows after nvim has been resized",
	})

	vim.api.nvim_create_autocmd({ "WinEnter", "WinClosed" }, {
		callback = function()
			vim.schedule(function()
				if vim.api.nvim_win_get_config(0).relative == "" then
					if vim.w.tz_pad_win == nil and vim.api.nvim_get_current_win() ~= win.main then
						local pad_sizes = {}
						pad_sizes.left = fix_padding("left", "width", vim.api.nvim_win_get_width(0))
						pad_sizes.right = fix_padding("right", "width", vim.api.nvim_win_get_width(0))
						pad_sizes.top = fix_padding("top", "height", vim.api.nvim_win_get_height(0))
						pad_sizes.bottom = fix_padding("bottom", "height", vim.api.nvim_win_get_height(0))

						if next(win) ~= nil then
							for point, dimension in pairs(CARDINAL_POINTS) do
								if vim.api.nvim_win_is_valid(win[point]) then
									if dimension == "width" then
										vim.api.nvim_win_set_width(win[point], pad_sizes[point])
									else
										vim.api.nvim_win_set_height(win[point], pad_sizes[point])
									end
								end
							end
						end
					else
						resize_layout()
					end
				end
			end)
		end,
		group = "TrueZenAtaraxis",
		desc = "Asser whether to resize TrueZen pad windows or not",
	})

	vim.fn.setpos(".", cursor_pos)
	M.running = true
	data.do_callback("ataraxis", "open", "post")
end

function M.off()
	if not M.running then
		return
	end

	data.do_callback("ataraxis", "close", "pre")

	local cursor_pos
	if vim.api.nvim_win_is_valid(win.main) then
		if win.main ~= vim.api.nvim_get_current_win() then
			vim.fn.win_gotoid(win.main)
		end
		cursor_pos = vim.fn.getpos(".")
	end

	vim.cmd("only")

	if vim.fn.filereadable(vim.fn.expand("%:p")) == 1 then
		vim.cmd("q")
	end

	blank.off()

	for k, v in pairs(original_opts) do
		vim.o[k] = v
	end

	for hi_group, props in pairs(original_highlights) do
		if hi_group == "just_bg" then
			for bg_hi_group, bg_props in pairs(original_highlights["just_bg"]) do
				colors.highlight(bg_hi_group, { bg = bg_props.background })
			end
		else
			colors.highlight(hi_group, { fg = props.foreground, bg = props.background }, true)
		end
	end

	vim.api.nvim_create_augroup("TrueZenAtaraxis", {
		clear = true,
	})

	for integration, val in pairs(config.integrations) do
		if (type(val) == "table" and val.enabled or val) == true and integration ~= "tmux" then
			require("true-zen.integrations." .. integration).off()
		end
	end

	if cursor_pos ~= nil then
		vim.fn.setpos(".", cursor_pos)
	end

	win = {}
	M.running = false
	data.do_callback("ataraxis", "close", "post")
end

function M.toggle()
	if M.running then
		M.off()
	else
		M.on()
	end
end

return M
