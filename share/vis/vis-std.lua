-- standard vis event handlers

vis.events.subscribe(vis.events.INIT, function()
	if os.getenv("TERM_PROGRAM") == "Apple_Terminal" then
		vis:command("set change-256colors false");
	end
	vis:command("set theme ".. (vis.ui.colors <= 16 and "default-16" or "default-256"))
end)

vis:option_register("theme", "string", function(name)
	if name ~= nil then
		local theme = 'themes/'..name
		package.loaded[theme] = nil
		require(theme)
	end

	vis.lexers.lexers = {}

	for win in vis:windows() do
		win:set_syntax(win.syntax)
	end
	return true
end, "Color theme to use, filename without extension")

vis:option_register("syntax", "string", function(name)
	if not vis.win then return false end
	if not vis.win:set_syntax(name) then
		vis:info(string.format("Unknown syntax definition: `%s'", name))
		return false
	end
	return true
end, "Syntax highlighting lexer to use")

vis:option_register("horizon", "number", function(horizon)
	if not vis.win then return false end
	vis.win.horizon = horizon
	return true
end, "Number of bytes to consider for syntax highlighting")

vis.events.subscribe(vis.events.WIN_HIGHLIGHT, function(win)
	if not win.syntax or not vis.lexers.load then return end
	local lexer = vis.lexers.load(win.syntax, nil, true)
	if not lexer then return end

	-- TODO: improve heuristic for initial style
	local viewport = win.viewport
	if not viewport then return end
	local horizon_max = win.horizon or 32768
	local horizon = viewport.start < horizon_max and viewport.start or horizon_max
	local view_start = viewport.start
	local lex_start = viewport.start - horizon
	local token_start = lex_start
	viewport.start = token_start
	local data = win.file:content(viewport)
	local token_styles = lexer._TOKENSTYLES
	local tokens = lexer:lex(data, 1)

	for i = 1, #tokens, 2 do
		local token_end = lex_start + tokens[i+1] - 1
		if token_end >= view_start then
			local name = tokens[i]
			local style = token_styles[name]
			if style ~= nil then
				win:style(style, token_start, token_end)
			end
		end
		token_start = token_end
	end
end)

local modes = {
	[vis.modes.NORMAL] = '',
	[vis.modes.OPERATOR_PENDING] = '',
	[vis.modes.VISUAL] = 'VISUAL',
	[vis.modes.VISUAL_LINE] = 'VISUAL-LINE',
	[vis.modes.INSERT] = 'INSERT',
	[vis.modes.REPLACE] = 'REPLACE',
}

vis.events.subscribe(vis.events.WIN_STATUS, function(win)
	local left_parts = {}
	local right_parts = {}
	local file = win.file
	local selection = win.selection

	local mode = modes[vis.mode]
	if mode ~= '' and vis.win == win then
		table.insert(left_parts, mode)
	end

	table.insert(left_parts, (file.name or '[No Name]') ..
		(file.modified and ' [+]' or '') .. (vis.recording and ' @' or ''))

	if #win.selections > 1 then
		table.insert(right_parts, selection.number..'/'..#win.selections)
	end

	local size = file.size
	local pos = selection.pos
	if not pos then pos = 0 end
	table.insert(right_parts, (size == 0 and "0" or math.ceil(pos/size*100)).."%")

	if not win.large then
		local col = selection.col
		table.insert(right_parts, selection.line..', '..col)
		if size > 33554432 or col > 65536 then
			win.large = true
		end
	end

	local left = ' ' .. table.concat(left_parts, " » ") .. ' '
	local right = ' ' .. table.concat(right_parts, " « ") .. ' '
	win:status(left, right);
end)

-- default plugins

require('plugins/filetype')
require('plugins/textobject-lexer')
require('plugins/digraph')
require('plugins/number-inc-dec')
require('plugins/complete-word')
require('plugins/complete-filename')
