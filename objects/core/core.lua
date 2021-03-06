--- the core manages lowish-level bootstrappy stuff, and fires important events.

--- EVENTS:
--- as you'd expect, this fires some essential events:
--[[ fired during initialization:
	<initialize>
		<loadUtilities>
			load essential utilities from the libs dir
		</loadUtilities>
		<loadConfig>
			load lua, followed by yaml config files from the config/ directory
		</loadConfig>
		<loadCore>
			load all objects in objects/core. basic, essential stuff.
		</loadCore>
		<loadPlugins>
			load all objects in objects/plugins. non-recursive.
		</loadPlugins>
	</initialize>
]]
--[[ fired during a request (when the server receives a request to view a page) or somesuch:
	<request>
		<route />
	</request>
]]
--[[ on total webylene shutdown:
	<shutdown />
]]

require "lfs"
local webylene = webylene
--- webylene core. this does all sorts of bootstrappity things.
local load_config, load_objects  --closured for fun and profit. mostly fun.
core = {
	--- initialize webylene
	initialize = function()
		local ev = webylene.event
		local logger = webylene.logger
		logger:info("started webylene " .. ((type(webylene.env)=="string") and ("in " .. webylene.env .. " environment") or "without an environment parameter") ..  " with path " .. webylene.path)
		
		ev:start("initialize")	
			ev:start("loadUtilities")
				require "utilities" -- we need all the random junk in here
			ev:finish("loadUtilities")
			
			--load config
			ev:start("loadConfig")
				load_config("config", "lua")
				load_config("config", "yaml")
			ev:finish("loadConfig")
		
			--load core objects
			ev:start("loadCore")
				load_objects("objects/core")
			ev:finish("loadCore")
			
			--load plugin objects
			ev:start("loadPlugins")
				load_objects("objects/plugins")
			ev:finish("loadPlugins")
		ev:finish("initialize")
	end,
	
	--- respond to a request
	request = function()
		local e = webylene.event
		e:start("request")
			e:fire("route")
		e:finish("request")
	end,
	
	shutdown = function()
		webylene.event:fire("shutdown")
	end
}
	
--- load config files of type <extension> from path <relative_path>. if <relative_path> is a folder, load all files with extension <extension>
--remember, this is local.
load_config = function(relative_path, extension)
	extension = extension or "yaml"
	local loadFile = {
		yaml = function(path)
			require "yaml"
			local f, err = io.open(path, "r")
			if not f then return nil, err end
			local success, conf = pcall(yaml.load, f:read("*all"))
			f:close()
			if not success then 
				local err = "Error loading yaml file " .. path ..":\n" .. conf
				logger:error(err)
				error(err, 0)
			end
			if conf.env and conf.env[webylene.env] then	
				table.mergeRecursivelyWith(conf, conf.env[webylene.env])
				conf.env = nil
			end
			table.mergeRecursivelyWith(webylene.config, conf)
		end,
		lua	= function(path)
			dofile(path)
		end
	}
	
	assert(loadFile[extension], "Config loader doesn't know what to do with the  \"." .. extension .. "\" extension.")
	local absolute_path = webylene.path .. webylene.path_separator .. relative_path
	for file in lfs.dir(absolute_path) do																				-- is this part right?...
		if file ~= "." and file ~= ".."  and lfs.attributes(absolute_path .. webylene.path_separator .. file, "mode")=="file" and file:sub(-#extension) == extension then
			loadFile[extension](absolute_path .. webylene.path_separator .. file)
		end
	end
	return true
end
	
--- load all objects in lua files in relativePath
--remember, this is local.
load_objects = function(relativePath)
	local absolutePath = webylene.path .. webylene.path_separator .. relativePath
	local webylene = webylene -- so that we don't have to go metatable-hopping all the time
	local extension = "lua"
	local extension_cutoff = #extension+2 --the dot +1
	for file in lfs.dir(absolutePath) do																				-- is this part right?...
		if file ~= "." and file ~= ".." and lfs.attributes(absolutePath .. webylene.path_separator .. file, "mode")=="file" and file:sub(-#extension) == extension then
			local obj = webylene[file:sub(1, -extension_cutoff)]
		end
	end
	return true
end
