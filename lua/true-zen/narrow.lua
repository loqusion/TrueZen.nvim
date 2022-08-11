local M = {}

local echo = require("true-zen.utils.echo")
local config = require("true-zen.config").options
local colors = require("true-zen.utils.colors")
local data = require("true-zen.utils.data")
local global = require("true-zen.global")
local FOLDS_STYLE = config.modes.narrow.folds_style

vim.g.active_buffs = 0
local original_opts = {}
local original_highlights

vim.api.nvim_create_augroup("TrueZenNarrow", {
	clear = true,
})

function M.custom_folds_style()
	if type(FOLDS_STYLE) == "function" then
		return FOLDS_STYLE
	elseif FOLDS_STYLE == "informative" then
		local v = vim.v
		local fold_count = v.foldend - v.foldstart + 1
		local prefix = "   " .. fold_count
		local separator = "   "
		return prefix .. separator .. vim.fn.getline(v.foldstart)
	end
	return ""
end

local function save_buffer_options()
	original_opts.foldenable = vim.wo.foldenable
	original_opts.foldmethod = vim.wo.foldmethod
	original_opts.foldminlines = vim.wo.foldminlines
	original_opts.foldtext = vim.wo.foldtext
	original_opts.fillchars = vim.wo.fillchars
end

local function normalize_line(line, mode)
	local pline = (mode == "head" and vim.fn.foldclosed(line) or vim.fn.foldclosedend(line))
	return (pline > 0 and pline or line)
end

function M.on(line1, line2)
	if vim.b.tz_narrowed_buffer then
		return
	end

	global.off()

	data.do_callback("narrow", "open", "pre")

	local saved_pos = vim.fn.getpos(".")

	local first_line = normalize_line(line1, "head")
	local last_line = normalize_line(line2, "tail")

	if vim.g.active_buffs <= 0 then
		save_buffer_options()
	end

	if FOLDS_STYLE == "invisible" then
		local bkg_color = colors.get_hl("Normal")["background"] or "NONE"
		colors.highlight("Folded", { fg = bkg_color, bg = bkg_color }, true)
		original_highlights = {
			Folded = colors.get_hl("Folded"),
		}
	end

	vim.b.tz_narrowed_buffer = true
	vim.wo.foldenable = true
	vim.wo.foldmethod = "manual"
	vim.wo.foldminlines = 0

	vim.cmd("normal! zE")

	if first_line > 1 then
		vim.cmd([[execute '1,' (]] .. first_line .. [[ - 1) 'fold']])
	end

	if last_line < vim.fn.line("$") then
		vim.cmd([[execute (]] .. last_line .. [[ + 1) ',$' 'fold']])
	end

	vim.wo.foldtext = 'v:lua.require("true-zen.narrow").custom_folds_style()'

	vim.fn.setpos(".", saved_pos)

	vim.cmd("normal! zz")

	if config.modes.narrow.run_ataraxis == true then
		if config.modes.ataraxis.quit_untoggles == true then
			vim.api.nvim_create_autocmd({ "QuitPre" }, {
				callback = function()
					M.off()
				end,
				group = "TrueZenNarrow",
			})
		end
		if vim.g.active_buffs <= 0 then
			require("true-zen.ataraxis").on()
		end
	end

	vim.wo.fillchars = (vim.o.fillchars ~= "" and vim.o.fillchars .. "," or "") .. "fold: "

	vim.g.active_buffs = vim.g.active_buffs + 1
	data.do_callback("narrow", "open", "post")
end

function M.off()
	if not vim.b.tz_narrowed_buffer then
		return
	end

	data.do_callback("narrow", "close", "pre")

	vim.g.active_buffs = (vim.g.active_buffs > 0 and vim.g.active_buffs or 1) - 1
	vim.b.tz_narrowed_buffer = nil

	if config.modes.narrow.run_ataraxis == true then
		if vim.g.active_buffs <= 0 then
			require("true-zen.ataraxis").off()
		end
	end

	local curr_pos = vim.fn.getpos(".")

	if vim.wo.foldmethod ~= "manual" then
		echo("'vim.wo.foldmethod' must be set to \"manual\"", "error")
	else
		vim.cmd("normal! zE")
	end

	vim.cmd("normal! zz")
	vim.fn.setpos(".", curr_pos)

	for k, v in pairs(original_opts) do
		vim.o[k] = v
	end

	if original_highlights ~= nil then
		for hi_group, props in pairs(original_highlights) do
			colors.highlight(hi_group, { fg = props.foreground, bg = props.background }, true)
		end
	end

	original_opts = {}
	original_highlights = {}
	data.do_callback("narrow", "close", "post")
end

function M.toggle(line1, line2)
	if vim.b.tz_narrowed_buffer then
		M.off()
	else
		M.on(line1, line2)
	end
end

return M
