-- Tree-sitter blocks for poi: nvim --headless -l outline.lua LISTFILE MAXLINES
-- LISTFILE holds one path per line. For each file, one JSON line on stdout:
--   {"file": ..., "lang": ..., "blocks": [[first, last, jump, "symbol chain"], ...], "outline": ["sym", ...]}
-- or {"file": ..., "error": ...} when there's no parser, so poi falls back to fixed windows.
-- Blocks are whole definitions (functions, classes, methods, Nix bindings, ...) when they fit in
-- MAXLINES; bigger ones are split into their children, and the code between definitions is packed
-- into blocks of its own. Comments right above a definition go with it. POI_TS_RTP (a folder with
-- parser/*.so) is put first on the runtimepath, so poi's Nix-built parsers win over the user's.
if vim.env.POI_TS_RTP and vim.env.POI_TS_RTP ~= "" then
	vim.opt.rtp:prepend(vim.env.POI_TS_RTP)
end
local MAX = tonumber(arg[2]) or 60
local MIN = 3 -- a definition shorter than this is packed with its neighbours

local NAMED = {
	function_definition = true, class_definition = true, -- python, bash (function_definition)
	function_declaration = true, class_declaration = true, method_definition = true, -- js/ts, lua, go
	abstract_class_declaration = true, interface_declaration = true, type_alias_declaration = true,
	enum_declaration = true, method_declaration = true, type_declaration = true, -- go
	function_item = true, struct_item = true, enum_item = true, trait_item = true, mod_item = true, -- rust
	impl_item = true, macro_definition = true,
	local_function = true, -- older lua grammars
	lexical_declaration = true, variable_declaration = true, -- const f = () => ...
	export_statement = true, decorated_definition = true,
	binding = true, inherit = false, -- nix
	section = true, -- markdown
}

local function first_line(s)
	return (s:match("^[^\n]*") or ""):gsub("%s+$", "")
end

local function defname(n, src)
	local t = n:type()
	if not NAMED[t] then
		return nil
	end
	local function field(f)
		local c = n:field(f)[1]
		return c and vim.treesitter.get_node_text(c, src) or nil
	end
	if t == "decorated_definition" then
		local d = n:field("definition")[1]
		return d and defname(d, src)
	elseif t == "export_statement" then
		local d = n:field("declaration")[1]
		return d and defname(d, src)
	elseif t == "lexical_declaration" or t == "variable_declaration" then
		for c in n:iter_children() do
			if c:type() == "variable_declarator" then
				local nm = c:field("name")[1]
				return nm and vim.treesitter.get_node_text(nm, src)
			end
		end
		return nil
	elseif t == "impl_item" then
		local ty, tr = field("type"), field("trait")
		return "impl " .. (tr and (tr .. " for ") or "") .. (ty or "?")
	elseif t == "binding" then
		return field("attrpath")
	elseif t == "section" then
		for c in n:iter_children() do
			if c:type():match("heading") then
				return first_line(vim.treesitter.get_node_text(c, src)):gsub("^#+%s*", "")
			end
		end
		return nil
	elseif t == "type_declaration" then
		for c in n:iter_children() do
			if c:type() == "type_spec" then
				local nm = c:field("name")[1]
				return nm and vim.treesitter.get_node_text(nm, src)
			end
		end
		return nil
	elseif t == "method_declaration" then
		return field("name")
	end
	local nm = field("name")
	return nm and first_line(nm)
end

-- 1-based first and last line; a node ending at column 0 ends on the line before.
local function span(n)
	local sr, _, er, ec = n:range()
	local b = (ec == 0 and er > sr) and er or er + 1
	return sr + 1, b
end

local function join(chain, name)
	local c = vim.deepcopy(chain)
	if name then
		table.insert(c, name)
	end
	return c
end

local function chunk(node, chain, src, out, outline)
	local cur -- run of small nodes: {a, b, comments_only}
	local function flush()
		if cur then
			table.insert(out, { cur.a, cur.b, cur.a, table.concat(chain, " > ") })
			cur = nil
		end
	end
	local any = false
	for child in node:iter_children() do
		if child:named() then
			any = true
			local a, b = span(child)
			local name = defname(child, src)
			local size = b - a + 1
			if name and #chain < 3 then
				table.insert(outline, table.concat(join(chain, name), " > ") .. "  (" .. a .. ")")
			end
			if size > MAX then
				flush()
				chunk(child, join(chain, name), src, out, outline)
			elseif name and size >= MIN then
				local first = a
				-- comments directly above a definition belong to it
				if cur and cur.comments and cur.b >= a - 1 and b - cur.a + 1 <= MAX then
					first = cur.a
					cur = nil
				end
				flush()
				table.insert(out, { first, b, a, table.concat(join(chain, name), " > ") })
			else
				if cur and b - cur.a + 1 > MAX then
					flush()
				end
				local is_comment = child:type():match("comment") ~= nil
				if not cur then
					cur = { a = a, b = b, comments = is_comment }
				else
					cur.b = math.max(cur.b, b)
					cur.comments = cur.comments and is_comment
				end
			end
		end
	end
	flush()
	if not any then -- a big leaf (a long string, say): fixed windows
		local a, b = span(node)
		for x = a, b, MAX do
			table.insert(out, { x, math.min(x + MAX - 1, b), x, table.concat(chain, " > ") })
		end
	end
end

local list = arg[1]
for path in io.lines(list) do
	local rec = { file = path }
	local ok, err = pcall(function()
		local ft = vim.filetype.match({ filename = path })
		local lang = ft and vim.treesitter.language.get_lang(ft)
		if not lang then
			error("no language")
		end
		local fh = assert(io.open(path, "rb"))
		local src = fh:read("*a")
		fh:close()
		local parser = vim.treesitter.get_string_parser(src, lang)
		local root = parser:parse()[1]:root()
		local out, outline = {}, {}
		chunk(root, {}, src, out, outline)
		table.sort(out, function(x, y)
			return x[1] < y[1]
		end)
		rec.lang, rec.blocks, rec.outline = lang, out, outline
	end)
	if not ok then
		rec.error = tostring(err):gsub("^.-:%d+: ", "")
	end
	io.stdout:write(vim.json.encode(rec), "\n")
end
