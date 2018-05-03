--[[
@description CS_ReaLauncher
@version 1.0
@author Claudiohbsantos
@link http://claudiohbsantos.com
@date 2017 06 19
@about
  # CS_ReaLauncher
  No Description Yet
@changelog
  - initial release
@noindex
--]]
---------------------------------------------------------------------------------------
rl = {}  
rl.textToPrint = {}
rl.registeredCommands = {}
rl.config = {}
rl.history = {}

rl.config.maxHistory = 50

rl.white = function(text) gfx.set(1,1,1,0.8,0) ; gfx.drawstr(text) return end
rl.grey = function(text) gfx.set(1,1,1,0.3,0) ; gfx.drawstr(text) return end
rl.red = function(text) gfx.set(1,0.6,0.6,0.8,0) ; gfx.drawstr(text) return end
rl.green = function(text) gfx.set(0.6,1,0.6,0.8,0) ; gfx.drawstr(text) return end
rl.blue = function(text) gfx.set(0.6,0.6,1,0.8,0) ; gfx.drawstr(text) return end

---------------------------------------------------------------------------------------

function get_script_path()
	local info = debug.getinfo(1,'S');
	local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
	return script_path
end 

---------------------------------------------------------------------------------------

function printText(text,color,typeOfUnit)
	table.insert(rl.textToPrint,{text = text,color = color,typeOfUnit = typeOfUnit})
end

function unprintLastText(n)
	for i=1,n+1,1 do table.remove(rl.textToPrint) end
end

function printHint(text,color)
	rl.previewToPrint = {text = text,color = color}
end

function iswindows()
	return reaper.GetOS():find('Win') ~= nil
end

function ismacos()
	return reaper.GetOS():find('OSX') ~= nil
end

function copy(text)
	local tool

	if ismacos() then
	tool = 'pbcopy'
	elseif iswindows() then
	tool = 'clip'
	end

	local proc = assert(io.popen(tool, 'w'))
	proc:write(text)
	proc:close()
end

function paste()
	local tool

	if ismacos() then
	tool = 'pbpaste'
	elseif iswindows() then
	tool = 'powershell -windowstyle hidden -Command Get-Clipboard'
	end

	local proc = assert(io.popen(tool, 'r'))
	local text = proc:read("*all")
	proc:close()

	return text
end

function updateActiveChar(string)
	rl.active_char = rl.active_char + string.len(string)
end

function LauncherTextBox(char)
	if not rl.active_char then rl.active_char = 0 end
	if not rl.text        then rl.text = '' end

	if  kbInput.isAnyPrintableSymbol(char) then        
	      rl.text = rl.text:sub(0,rl.active_char)..
	        string.char(char)..
	        rl.text:sub(rl.active_char+1)
	      rl.active_char = rl.active_char + 1
	end

	if char == kbInput.copy then
		copy(rl.text)
	end

	if char == kbInput.paste then
		local pasteString = paste()
		rl.text = rl.text..pasteString
		updateActiveChar(pasteString)
	end

	 if char == kbInput.backspace then
	    rl.text = rl.text:sub(0,rl.active_char-1)..
	      rl.text:sub(rl.active_char+1)
	    rl.active_char = rl.active_char - 1
	  end

	  if char == kbInput.deleteKey then
	    rl.text = rl.text:sub(0,rl.active_char)..
	      rl.text:sub(rl.active_char+2)
	    rl.active_char = rl.active_char
	  end
	        
	  if char == kbInput.leftArrow then
	    rl.active_char = rl.active_char - 1
	  end
	  
	  if char == kbInput.rightArrow then
	    rl.active_char = rl.active_char + 1
	  end

	if rl.active_char < 0 then rl.active_char = 0 end
	if rl.active_char > rl.text:len()  then rl.active_char = rl.text:len() end
end

function recallHistory(char)
	if char == kbInput.upArrow then	
		if not rl.history.recalledPosition then 
			rl.history.recalledPosition = #rl.history 
		else
			rl.history.recalledPosition = rl.history.recalledPosition - 1
			if rl.history.recalledPosition < 1 then rl.history.recalledPosition = 1 end
		end
		rl.text = rl.history[rl.history.recalledPosition]
	end

	if char == kbInput.downArrow then
		if not rl.history.recalledPosition then 
			rl.history.recalledPosition = #rl.history
		else
			rl.history.recalledPosition = rl.history.recalledPosition + 1
			if rl.history.recalledPosition > #rl.history then rl.history.recalledPosition = #rl.history end
		end
		rl.text = rl.history[rl.history.recalledPosition]
	end
end

function getShortcuts(char)
	if char == kbInput.ctrl.s then rl.text = rl.text.."selItem" ; updateActiveChar("selItem") end
end

function rl.timeInput(defaultTimeToDisplay)
	rl.drawCursor = false
	rl.customInput = true
	if not tcInput then initTimeInput() end
	
	TCTextBox(char) 

	local _,userInputString = getTimeInput(tcInput.text,defaultTimeToDisplay)

	if userInputString then
		rl.drawCursor = true
		rl.customInput = nil
		rl.registeredCommands[rl.command][rl.waitingForCustomInput] = userInputString
		rl.text = rl.text.." " 
		rl.active_char = rl.active_char+1
		rl.text = rl.text..userInputString
		updateActiveChar(userInputString)
		rl.tipLine = nil
		tcInput = nil
	end
end

function autocomplete()
	if rl.currentAutocomplete and char == kbInput.tab then 
		rl.text = rl.text..rl.currentAutocomplete 
		updateActiveChar(rl.currentAutocomplete )
		rl.previewToPrint = nil
		rl.currentAutocomplete = nil 
		CommandDispatcher(rl.text)
	end
end


function mergeSortMatrixDescending(matrix,keyForSorting)
	local matrixLength = #matrix
	local subMatrix = {}
	for i = 1,matrixLength,1 do
		subMatrix[i] = {}
		subMatrix[i][1] = matrix[i]
	end

	while #subMatrix[1] < matrixLength do
		local i = 1
		while i <= #subMatrix do
			local a = i
			local b = i+1
			if subMatrix[b] then 
				local buffer = {}
				local nElementsToCompare = #subMatrix[a] + #subMatrix[b]
				while #buffer < nElementsToCompare do
					if subMatrix[a][1] and subMatrix[b][1] then
						if subMatrix[a][1][keyForSorting] > subMatrix[b][1][keyForSorting] then
							table.insert(buffer,subMatrix[a][1])
							table.remove(subMatrix[a],1)
						else
							table.insert(buffer,subMatrix[b][1])
							table.remove(subMatrix[b],1)
						end
					else
						if subMatrix[a][1] then 
							table.insert(buffer,subMatrix[a][1])
							table.remove(subMatrix[a],1)
						end
						if subMatrix[b][1] then 
							table.insert(buffer,subMatrix[b][1])
							table.remove(subMatrix[b],1)
						end
					end
				end
				subMatrix[a] = buffer
				table.remove(subMatrix,b)
			end
			i = i + 1
		end
	end
	local sortedMatrix = subMatrix[1]
	return sortedMatrix
end


function sortMatches(matches)
	local sortedMatches = mergeSortMatrixDescending(matches,"percentageOfProximityToArguments") 

	return sortedMatches
end

function removeExcludeWords(searchArgumentsTable)
	local nonExclude = {}
	for i=1, #searchArgumentsTable,1 do
		if not string.match(searchArgumentsTable[i],"^-.*") then 
			nonExclude[#nonExclude+1] = searchArgumentsTable[i]
		end
	end

	return nonExclude
end

function calculatePercentageOfProximityToArguments(databaseEntry,searchArgumentsTable)
	local validWords = removeExcludeWords(searchArgumentsTable)

	local argumentsLength = 0
	for i=1,#validWords,1 do

		local repetitions = 0
		for match in string.gmatch(databaseEntry,validWords[i]) do
			repetitions = repetitions + 1
		end

		argumentsLength = argumentsLength + ( string.len(validWords[i]) * repetitions ) 
	end

	local spaces = 0
	for space in string.gmatch(databaseEntry,"%s") do
		spaces = spaces + 1
	end
	entryLength = string.len(databaseEntry) - spaces

	local percentageOfProximity = argumentsLength / entryLength

	percentageOfProximity = string.format("%.2f",percentageOfProximity)

	return percentageOfProximity

end

function searchUnorderedListForExactMatchesAndReturnMatchesTable(databaseList,searchArgumentsTable)
	local matches = {}

	for key,value in pairs(databaseList) do
		local isMatch
		for k,searchArg in ipairs(searchArgumentsTable) do
			if string.match(searchArg,"^-.*") then
				local excludeWord = string.sub(searchArg,2)
				if string.match(key,"^"..excludeWord) then
					isMatch = false
					break
				end				
			else
				if  string.match(key,"^"..searchArg) then
					isMatch = true
				else
					isMatch = false
				end
			end
		end

		if isMatch then
			
			local percentageOfProximityToArguments = calculatePercentageOfProximityToArguments(key,searchArgumentsTable)

			table.insert(matches,{match = key,percentageOfProximityToArguments = percentageOfProximityToArguments})
			matches[#matches].percentageOfProximityToArguments = percentageOfProximityToArguments
		end
	end


	return matches
end

function searchMatrixAndReturnMatchesTable(databaseMatrix,searchArgumentsTable,keyToSearchIn)
	local matches = {}


	for i = 1, #databaseMatrix, 1 do
		local isMatch
		for k = 1, #searchArgumentsTable, 1 do
			if string.match(searchArgumentsTable[k],"^-.*") then
				local excludeWord = string.sub(searchArgumentsTable[k],2)
				if string.find(databaseMatrix[i][keyToSearchIn],excludeWord) then
					isMatch = false
					break
				end				
			else
				if  string.find(databaseMatrix[i][keyToSearchIn],searchArgumentsTable[k]) then
					isMatch = true
				else
					isMatch = false
					break
				end
			end
		end

		if isMatch then
			matches[#matches+1] = databaseMatrix[i]

			local percentageOfProximityToArguments = calculatePercentageOfProximityToArguments(databaseMatrix[i][keyToSearchIn],searchArgumentsTable)
			matches[#matches].percentageOfProximityToArguments = percentageOfProximityToArguments
		end
	end

	return matches
end
---------------------------------------------------------------------------------------    

function storeAndPrintArgumentUnit(argumentUnit,command)
	if rl.nextIsParam then
		unprintLastText(string.len(argumentUnit))
		printText(argumentUnit.." ","green","SwitchParam") 
		if string.sub(argumentUnit,1,1) == "\"" then argumentUnit = string.sub(argumentUnit,2,-2) end
		rl.registeredCommands[command][rl.nextIsParam] = argumentUnit
		rl.previewToPrint = nil
		rl.nextIsParam = nil
	else
		local isSwitch = false
		if rl.registeredCommands[command].switches then
			for switch in pairs(rl.registeredCommands[command].switches) do
				if argumentUnit  == ("/"..switch) or argumentUnit == ("--"..switch) then
					isSwitch = true
					unprintLastText(string.len(argumentUnit))
					printText(argumentUnit.." ","blue","Switch")

					if type(rl.registeredCommands[command].switches[switch]) == "boolean" then
						rl.registeredCommands[command][switch] = true
					else
						if type(rl.registeredCommands[command].switches[switch]) == "function" then
							rl.waitingForCustomInput = switch
							if not rl.registeredCommands[command][switch] then rl.registeredCommands[command].switches[switch]() end
						else
							rl.nextIsParam = switch
							printHint(" ("..rl.registeredCommands[command].switches[switch]..")","grey")
						end
					end
				end
			end
		end
		if not isSwitch then 
			unprintLastText(string.len(argumentUnit))
			printText(argumentUnit.." ","green","Element") 
			if string.sub(argumentUnit,1,1) == "\"" then argumentUnit = string.sub(argumentUnit,2,-2) end
			rl.argumentElement[#rl.argumentElement + 1] = argumentUnit
		end
	end	
end

function matchAndStoreArguments(command,arguments)
	rl.arguments = arguments
	if string.sub(arguments,-1,-1) ~= " " then arguments = arguments.." " end
	rl.argumentElement = {}	
	local argumentUnit = ""
	rl.quoteOpen = false
	rl.nextIsParam = nil
	for i=1,string.len(arguments),1 do
		currentChar = string.sub(arguments,i,i)
		if string.find(currentChar," ") then
			if not rl.quoteOpen then 
				printText(currentChar,"white","Space")
				if not string.match(argumentUnit,"^ $") and string.len(argumentUnit) > 0 then storeAndPrintArgumentUnit(argumentUnit,command) end
				argumentUnit = ""
			else
				printText(currentChar,"white","Space")
				argumentUnit = argumentUnit..currentChar 
			end
		else
			printText(currentChar,"green","Uncategorized")
			if string.find(currentChar,"\"") then rl.quoteOpen = not rl.quoteOpen end
			argumentUnit = argumentUnit..currentChar
			if string.match(argumentUnit,"^/.*") and rl.registeredCommands[command].switches then suggestSwitch(string.sub(argumentUnit,2),command) end
			if string.match(argumentUnit,"^%-%-.*") and rl.registeredCommands[command].switches then suggestSwitch(string.sub(argumentUnit,3),command) end
		end
	end
end

function matchAndStore(command,arguments)
	rl.previewToPrint = nil
	if rl.registeredCommands[command] and string.match(rl.text,"^%s*[^%s]+( )") then
		rl.currentAutocomplete = nil
		rl.textToPrint = {}
		rl.command = command
		printText(command.." ","red","Command")
		if arguments and string.len(arguments) > 0 then
			matchAndStoreArguments(command,arguments)			
		else
			rl.arguments = nil
			if rl.registeredCommands[command].customArg then
				rl.waitingForCustomInput = "customArgInput"
				if not arguments then rl.registeredCommands[command].customArg() end
			end
		end	
	else -- command not found
		if not arguments then suggestCommand(command) else rl.currentAutocomplete = nil ; rl.previewToPrint = nil end
		rl.command = nil
		rl.arguments = nil
	end
end

function CommandDispatcher(text)
	if not text then return end

	local command = string.match(text,"^%s*([^%s]+)")
	local arguments = string.match(text,"^%s*[^%s]+ (.+)")

	matchAndStore(command,arguments)
end

function suggestSwitch(word,command)
	local switchMatches = searchUnorderedListForExactMatchesAndReturnMatchesTable(rl.registeredCommands[command].switches,{word})
	if #switchMatches > 0 then 
		switchMatches = mergeSortMatrixDescending(switchMatches,"percentageOfProximityToArguments") 

		local suggestion = string.sub(switchMatches[1].match,string.len(word)+1)

		printHint(suggestion,"grey")
		rl.currentAutocomplete = suggestion
	else
		rl.previewToPrint = nil
		rl.currentAutocomplete = nil 
	end
end

function suggestCommand(command)
	local commandMatches = searchUnorderedListForExactMatchesAndReturnMatchesTable(rl.registeredCommands,{command})
	if #commandMatches > 0 then 
		commandMatches = mergeSortMatrixDescending(commandMatches,"percentageOfProximityToArguments")

		local suggestion = string.sub(commandMatches[1].match,string.len(command)+1)
		printHint(suggestion,"grey")
		rl.currentAutocomplete = suggestion
	else 
		rl.currentAutocomplete = nil
		rl.previewToPrint = nil
	end
end

function drawWindow()
    gfx.set(  1,1,1,  0.2,  0) --rgb a mode
    gfx.rect(0,0,obj_mainW,obj_mainH,1)	
    gfx.set(  1,1,1,  0.1,  0) --rgb a mode
    gfx.rect(obj_offs,obj_offs,obj_mainW-obj_offs*2,gui_fontsize+obj_offs/2 ,1)
end

function drawText()
    gfx.setfont(1, gui_fontname, gui_fontsize)
    gfx.x = obj_offs*2
    gfx.y = obj_offs
    if rl.command then
    	if string.match(rl.textToPrint[#rl.textToPrint].text,".* $") then rl.textToPrint[#rl.textToPrint].text = string.sub(rl.textToPrint[#rl.textToPrint].text,1,-2) end
		for i=1,#rl.textToPrint,1 do
			rl[rl.textToPrint[i].color](rl.textToPrint[i].text)
		end
	else
		rl.white(rl.text)
    end
    if rl.previewToPrint then
    	rl[rl.previewToPrint.color](rl.previewToPrint.text)
    end
end

function drawCursor()
	if rl.active_char ~= nil then
    	alpha  = math.abs((os.clock()%1) -0.4)
      gfx.set(  1,1,1, alpha,  0) --rgb a mode
      gfx.x = obj_offs*1.5+
              gfx.measurestr(rl.text:sub(0,rl.active_char)) + 2
      gfx.y = obj_offs + gui_fontsize/2 - gfx.texth/2
      if rl.drawCursor then gfx.drawstr('|') end
    end  
end

function drawTip(text)
	gfx.setfont(1, gui_fontname, gui_fontsize)
    gfx.x = obj_offs*2
    gfx.y = obj_offs + 32
    gfx.set(1,1,1,0.3,0)
    gfx.drawstr(tostring(text))
end

function drawGUI()
	drawWindow()
	drawText()
	drawCursor()
	-- drawArgumentsAutocomplete(rl.argSuggestion)
	if not rl.tipLine then
		if rl.command and rl.registeredCommands[rl.command].description then rl.tipLine = rl.registeredCommands[rl.command].description end	
	end
	if rl.tipLine then drawTip(rl.tipLine) end
end

function saveHistory()
	if rl.command then
		os.execute([[mkdir "]]..rl.userSettingsPath..[["]])
		
		table.insert(rl.history,rl.text)
		local offset
		if #rl.history - rl.config.maxHistory + 1 < 1 then
			offset = 1
		else
			offset = #rl.history - rl.config.maxHistory + 1
		end

		local historyFile = io.open(rl.userSettingsPath.."\\history.txt","w")
		for i = offset, #rl.history, 1 do
			historyFile:write(rl.history[i].."\n")
		end
		historyFile:close()
	end
end

function exitRoutine()
	saveHistory()
	if rl.executeOnExit then
		if type(rl.executeOnExit) == "table" then
			rl.executeOnExit[1](table.unpack(rl.executeOnExit,2))
		else
			rl.executeOnExit()
		end
	end
end
function loadhistory()
	local historyFile = io.open(rl.userSettingsPath.."\\history.txt","r")
	for command in historyFile:lines() do 
		if command ~= "\n" then table.insert(rl.history,command) end
	end
end

---------------------------------------------------------------------------------------    

function Run()
	char  = gfx.getchar()
	if not rl.customInput then
		LauncherTextBox(char) -- perform typing
		recallHistory(char)
		getShortcuts(char)
		rl.text = string.match(rl.text,"^%s*([^%s]?.*)")
	end
	if char > 0  
		    and rl.text 
		    and char ~=  kbInput.rightArrow
		    and char ~= kbInput.leftArrow then 
		    	CommandDispatcher(rl.text)
		  end
	if rl.command then
		if rl.registeredCommands[rl.command].waitForEnter then 
			if char == kbInput.enter then CommandDispatcher(rl.text) ; rl.registeredCommands[rl.command].main(rl.arguments) end
		else
			rl.registeredCommands[rl.command].main(rl.arguments)
		end
	end
	drawGUI()
	autocomplete()
	gfx.update()
	last_char = char
	if char ~= -1 and char ~= 27 and char ~= kbInput.enter then reaper.defer(Run) else gfx.quit() end
end 

---------------------------------------------------------------------------------------
function loadModules()
	rl.scriptPath = get_script_path()
	rl.userSettingsPath = rl.scriptPath.."\\User"

	package.path = package.path .. ";" .. rl.scriptPath .. "?.lua"

	for file in io.popen([[dir "]]..rl.scriptPath..[[" /b]]):lines() do 
		if string.match(file,"_LaunchModule.lua$") or string.match(file,"_Library.lua$") then 
			local LaunchModule = string.match(file,"(.*)%.lua")
			require(LaunchModule)
		end
	end
end

function loadSettings()
	loadhistory()
end

function initLauncherGUI()
	obj_mainW = 800	
	obj_mainH = 70
	obj_offs = 10
	
	gui_aa = 1
	gui_fontname = 'Calibri'
	gui_fontsize = 23      
	local gui_OS = reaper.GetOS()
	if gui_OS == "OSX32" or gui_OS == "OSX64" then gui_fontsize = gui_fontsize - 7 end

	Lokasenna_WindowAtCenter(obj_mainW,obj_mainH)
	rl.drawCursor = true
end

function Lokasenna_WindowAtCenter(w, h)
	-- thanks to Lokasenna 
	-- http://forum.cockos.com/showpost.php?p=1689028&postcount=15    
	local l, t, r, b = 0, 0, w, h    
	local __, __, screen_w, screen_h = reaper.my_getViewport(l, t, r, b, l, t, r, b, 1)    
	local x, y = (screen_w - w) / 2, (screen_h - h) / 2    
	gfx.init("ReaLauncher", w, h, 0, x, y)  
end

-- SHOW TIME! --

loadModules()
loadSettings()
initLauncherGUI()
Run()
reaper.atexit(exitRoutine)