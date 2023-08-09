require "json"
JSON=(loadstring(json.JSON_LIBRARY_CHUNK))()

ZEEVEE = {
	MAX_INPUTS = 64,
	MAX_OUTPUTS = 64,
	ENDPOINT = "http://" .. Properties["IP Address"] .. "/rcCmd.php",
	HEADERS = {
		['Content-Type'] = "application/x-www-form-urlencoded"
	},
	POSTDATA = "username=" .. Properties["Username"] .. "&" .. "password=" .. Properties["Password"] .. "&serverSocketName=rcServerSocket&commands="
}

function ZEEVEE.PULSE(tParams, idBinding)
	local cmd = "send " .. Properties["Output " .. string.format("%02d",idBinding % 100) .. " Name"] .. " ir " .. string.gsub(ReturnStringBetween(tParams["data"], "<pattern>", "</pattern>")," ","") .. ""
	C4:urlPost(ZEEVEE.ENDPOINT, ZEEVEE.POSTDATA .. string.gsub(cmd," ","+"), ZEEVEE.HEADERS, false, ZEEVEE.PROCESS_GENERIC)
end

function ZEEVEE.SEND(tParams,idBinding)
	local data = C4:Base64Decode(tParams["data"])
	local cmd = "send " .. Properties["Output " .. string.format("%02d",idBinding % 100) .. " Name"] .. " rs232 \"" .. data .. "\""
	C4:urlPost(ZEEVEE.ENDPOINT, ZEEVEE.POSTDATA .. string.gsub(cmd," ","+"), ZEEVEE.HEADERS, false, ZEEVEE.PROCESS_GENERIC)
end

function ZEEVEE.AUTO_SETUP()
	local cmd = "show device status all"
	C4:urlPost(ZEEVEE.ENDPOINT, ZEEVEE.POSTDATA .. string.gsub(cmd," ","+"), ZEEVEE.HEADERS, false, ZEEVEE.PROCESS_AUTO_SETUP)
end

function ZEEVEE.PROCESS_AUTO_SETUP(ticketId, strData, responseCode, tHeaders)
	Dbg(strData)
	local o,encoder,decoder = JSON:decode(strData),0,0
	if(o.status == "Success") then
		for _,response in pairs(o.responses) do
			if(response.text ~= nil) then
				for _,device in pairs(response.text) do
					if(device.gen ~= nil) then
						if(device.gen.type == "encoder") then
							encoder = encoder + 1
							C4:UpdateProperty("Input " .. string.format("%02d", encoder) .. " Name", device.gen.name)
						elseif(device.gen.type == "decoder") then
							decoder = decoder + 1
							C4:UpdateProperty("Output " .. string.format("%02d", decoder) .. " Name", device.gen.name)
						end
					end
				end
			end
		end
		C4:UpdateProperty("Number of Inputs", encoder)
		C4:UpdateProperty("Number of Outputs", decoder)
		ZEEVEE.HIDE_INPUTS()
		ZEEVEE.HIDE_OUTPUTS()
	else
		Dbg("COMMAND FAILURE")
	end
end

function ZEEVEE.GET_INFO()
	local cmd = "show server info"
	C4:urlPost(ZEEVEE.ENDPOINT, ZEEVEE.POSTDATA .. string.gsub(cmd," ","+"), ZEEVEE.HEADERS, false, ZEEVEE.PROCESS_INFO)
end


function ZEEVEE.PROCESS_SET_232(ticketId, strData, responseCode, tHeaders)
	Dbg(strData)
	local o = JSON:decode(strData)
	if(o.status == "Success") then
		for _,response in pairs(o.responses) do
			if(response.warnings ~= nil) then
				for a,b in pairs(response.warnings) do
					if(string.find(b,"restart")) then
						ZEEVEE.RESTART_DEVICE(lastDevice)
					end
				end
			end
		end
	else
		Dbg("COMMAND FAILURE")
	end
end

function ZEEVEE.PROCESS_INFO(ticketId, strData, responseCode, tHeaders)
	Dbg(strData)
	local o = JSON:decode(strData)
	if(o.status == "Success") then
		for _,response in pairs(o.responses) do
			if(response.text ~= nil) then
				if(response.text.gen ~= nil) then
					C4:UpdateProperty("Version", response.text.gen.version)
					C4:UpdateProperty("Serial Number", response.text.gen.serialNumber)
				end
			end
		end
	else
		Dbg("COMMAND FAILURE")
	end
end

function ZEEVEE.GET_DEVICE_CONFIG()
	local cmd = "show device config decoders"
	C4:urlPost(ZEEVEE.ENDPOINT, ZEEVEE.POSTDATA .. string.gsub(cmd," ","+"), ZEEVEE.HEADERS, false, ZEEVEE.PROCESS_CONFIG)
end

function ZEEVEE.PROCESS_CONFIG(ticketId, strData, responseCode, tHeaders)
	Dbg(strData)
	local o = JSON:decode(strData)
	if(o.status == "Success") then
		for _,response in pairs(o.responses) do
			if(response.text ~= nil) then
				for _,text in pairs(response.text) do
					local decoderName, encoderName = "",""
					if(text.gen ~= nil) then
						decoderName = text.gen.name
					end
					if(text.connectedEncoder ~= nil) then
						encoderName = text.connectedEncoder.name
					end
					if(encoderName ~= "" and decoderName ~= "") then
						local encoderInput, decoderOutput = 0,0
						for a = 1, tonumber(Properties["Number of Inputs"]), 1 do
							if(Properties["Input " .. string.format("%02d", a) .. " Name"] == encoderName) then
								encoderInput = a
							end
						end
						for a = 1, tonumber(Properties["Number of Outputs"]), 1 do
							if(Properties["Output " .. string.format("%02d", a) .. " Name"] == decoderName) then
								decoderOutput = a
							end
						end
						Dbg("Setting output " .. decoderOutput .. "(" .. decoderName .. ")" .. " to input " .. encoderInput .. " (" .. encoderName .. ")")
						C4:SendToProxy(5001, 'INPUT_OUTPUT_CHANGED', {INPUT = encoderInput + 999, OUTPUT = decoderOutput + 1999, AUDIO=false, VIDEO=true} )  
					end
				end
			end
		end
	else
		Dbg("COMMAND FAILURE")
	end
end

function ZEEVEE.SET_VIDEO_WALL_MODE(encoder, mode)
	local cmd = "set video-wall-encoder " .. encoder .. " " .. mode
	C4:urlPost(ZEEVEE.ENDPOINT, ZEEVEE.POSTDATA .. string.gsub(cmd," ","+"), ZEEVEE.HEADERS, false, ZEEVEE.PROCESS_GENERIC)
end

function ZEEVEE.PROCESS_GENERIC(ticketId, strData, responseCode, tHeaders)
	Dbg(strData)
end

function ZEEVEE.SET_INPUT(tParams)
	local input = (tParams.INPUT % 100) + 1
	local output = (tParams.OUTPUT % 100) + 1
	ZEEVEE.SET_JOIN(Properties["Input " .. string.format("%02d",input) .. " Join Type"],Properties["Input " .. string.format("%02d",input) .. " Name"],Properties["Output " .. string.format("%02d",output) .. " Name"])
	C4:SendToProxy(5001, 'INPUT_OUTPUT_CHANGED', {INPUT = tParams.INPUT, OUTPUT = tParams.OUTPUT, AUDIO=false, VIDEO=true} )  
end

function ZEEVEE.DISCONNECT_OUTPUT(tParams)
	local output = (tParams.OUTPUT % 100) + 1
	ZEEVEE.SET_JOIN(Properties["Input " .. string.format("%02d",input) .. " Join Type"],"none",Properties["Output " .. string.format("%02d",output) .. " Name"])
	C4:SendToProxy(5001, 'INPUT_OUTPUT_CHANGED', {INPUT = 0, OUTPUT = tParams.OUTPUT, AUDIO=false, VIDEO=true} )  
end

function ZEEVEE.SET_JOIN(mode,input,output)
	if(mode ~= "manual") then
		local cmd = "join " .. input .. " " .. output .. " " .. mode
		C4:urlPost(ZEEVEE.ENDPOINT, ZEEVEE.POSTDATA .. string.gsub(cmd," ","+"), ZEEVEE.HEADERS, false, ZEEVEE.PROCESS_GENERIC)
	end
end

function ZEEVEE.HIDE_OUTPUTS()
	local n = tonumber(Properties["Number of Outputs"])
	for a=1,n,1 do
		C4:SetPropertyAttribs("Output " .. string.format("%02d",a) .. " Name",0)
	end
	if (n ~= ZEEVEE.MAX_OUTPUTS) then
		for a=n+1,ZEEVEE.MAX_OUTPUTS,1 do
			C4:SetPropertyAttribs("Output " .. string.format("%02d",a) .. " Name",1)
		end
	end
end

function ZEEVEE.HIDE_INPUTS()
	local n = tonumber(Properties["Number of Inputs"])
	for a=1,n,1 do
		C4:SetPropertyAttribs("Input " .. string.format("%02d",a) .. " Join Type",0)
		C4:SetPropertyAttribs("Input " .. string.format("%02d",a) .. " Name",0)
	end
	if (n ~= ZEEVEE.MAX_INPUTS) then
		for a=n+1,ZEEVEE.MAX_INPUTS,1 do
			C4:SetPropertyAttribs("Input " .. string.format("%02d",a) .. " Join Type",1)
			C4:SetPropertyAttribs("Input " .. string.format("%02d",a) .. " Name",1)
		end
	end
end

function ZEEVEE.SET_232_SETTINGS(output, settings)
	local baudSettings = StringTokenise(settings," ", false)
	local cmd = "set device " .. output .. " rs232 " .. tonumber(baudSettings[1]) .. " " .. tonumber(baudSettings[2]) .. "-bits " .. tonumber(baudSettings[4]) .. "-stop " .. string.lower(baudSettings[5])
	C4:urlPost(ZEEVEE.ENDPOINT, ZEEVEE.POSTDATA .. string.gsub(cmd," ","+"), ZEEVEE.HEADERS, false, ZEEVEE.PROCESS_SET_232)
	lastDevice = output
end

function ZEEVEE.RESTART_DEVICE(device)
	local cmd = "restart device " .. device
	C4:urlPost(ZEEVEE.ENDPOINT, ZEEVEE.POSTDATA .. string.gsub(cmd," ","+"), ZEEVEE.HEADERS, false, ZEEVEE.PROCESS_GENERIC)
end

function OnBindingChanged(idBinding, strClass, bIsBound)
	Dbg("OnBindingChanged: " .. idBinding, strClass, bIsBound)
	if (bIsBound) then
		if (strClass == "RS_232") then  
			ZEEVEE.SET_232_SETTINGS(Properties["Output " .. string.format("%02d", idBinding % 100) .. " Name"], GetSerialSettings(idBinding))
		elseif(strClass == "IR_OUT") then  
		end
	else
		if (strClass == "RS_232") then  
		elseif(strClass == "IR_OUT") then  
		end
	end
end

function ReceivedFromProxy(idBinding, strCommand, tParams)
	if(tParams == nil) then
		Dbg("ReceivedFromProxy(" .. idBinding .. "," .. strCommand .. ",{})")
	else
		local c = ""
		for a,b in pairs(tParams) do c = c .. "['" .. a .. "'] = \"" .. b .. "\"," end
		Dbg("ReceivedFromProxy(" .. idBinding .. "," .. strCommand .. ",{" .. string.sub(c,1,-2) .. "})")
	end
	if (type(ZEEVEE[strCommand])=='function') then
		ZEEVEE[strCommand](tParams,idBinding)
	elseif (ZEEVEE[strCommand] ~= nil) then
		local cmd = ZEEVEE[strCommand]
		C4:urlPost(ZEEVEE.ENDPOINT, ZEEVEE.POSTDATA .. string.gsub(cmd," ","+"), ZEEVEE.HEADERS, false, ZEEVEE.PROCESS_INFO)
	else
		Dbg('Proxy Command not defined: '.. strCommand)
	end
end

function OnPropertyChanged(strProperty)
	if(strProperty == "IP Address") then
		if(string.len(Properties["IP Address"]) > 0) then
			ZEEVEE.ENDPOINT = "http://" .. Properties["IP Address"] .. "/rcCmd.php"
		end
		ZEEVEE.GET_INFO()
		ZEEVEE.AUTO_SETUP()
	elseif(strProperty == "Username" or strProperty == "Password") then
		ZEEVEE.POSTDATA = "username=" .. Properties["Username"] .. "+" .. "password=" .. Properties["Password"] .. "+serverSocketName=rcServerSocket+commands="
	elseif(strProperty == "Control4 MAC Address") then
		C4:UpdateProperty("Control4 MAC Address", C4:GetUniqueMAC())
	elseif(strProperty == "Number of Inputs") then
		ZEEVEE.HIDE_INPUTS()
	elseif(strProperty == "Number of Outputs") then
		ZEEVEE.HIDE_OUTPUTS()
	end
end

function OnTimerExpired(idTimer)
	if(idTimer == pollTimer) then
		ZEEVEE.GET_DEVICE_CONFIG()
	end
end

function ExecuteCommand(strCommand, tParams)
	Dbg(strCommand)
	for a,b in pairs(tParams) do
		Dbg(a,b)
	end
	if(strCommand == "Select Multiview Mode") then
		ZEEVEE.SET_MULTIVIEW_MODE(tParams["Encoder Name"],tParams["Multiview Name"])
	elseif(strCommand == "Select Video Wall Mode") then
		ZEEVEE.SET_VIDEO_WALL_MODE(tParams["Encoder Name"],tParams["Video Wall Name"])
	elseif(strCommand == "Join") then
		ZEEVEE.SET_JOIN(tParams["Mode"],tParams["Encoder Name"],tParams["Decoder Name"])
	elseif(strCommand == "LUA_ACTION" and tParams.ACTION == "Auto Setup") then
		ZEEVEE.AUTO_SETUP()
	end
end

function OnDriverLateInit()
	pollTimer = C4:AddTimer(1,"MINUTES",true)
	C4:UpdateProperty("Control4 MAC Address", C4:GetUniqueMAC())
	ZEEVEE.HIDE_INPUTS()
	ZEEVEE.HIDE_OUTPUTS()
	for	a=1,ZEEVEE.MAX_OUTPUTS,1 do
		C4:AddVariable("VIDEO_OUTPUT_" .. string.format("%02d",a) .. "_INPUT", 0, "NUMBER", true, false)
	end
end

function Dbg(debugString, ... )
	if (Properties["Debug Mode"] == "Print") then
		print(debugString, ... )
	end
end

function GetSerialSettings(idBinding)
	local id  = C4:GetBoundConsumerDevices(C4:GetDeviceID(),idBinding)
	for ParamName, ParamValue in pairs(id) do id = ParamName end	
	return C4:GetDeviceData(id, "serialsettings")
end


function StringTokenise(str, seperator, skipEmpty)
	if(string.find(str, seperator)) then
	else
		return {[1] = str}
	end
    local start = 1
    local pos = 1
    local tokens = {"", ""}
    local i = 1

    while (str ~= nil) do
        pos = string.find(str, seperator, start)

        if (pos ~= nil) then
            if (skipEmpty ~= true) or
               (pos > start + 1) then
                tokens[i] = string.sub(str, start, pos - 1)
                i = i + 1
            end

            start = pos + 1
        else
            tokens[i] = string.sub(str, start)
            break
        end
    end

    return tokens
end

function ReturnStringBetween(originalString, a, b)
    local c = ""
    c = string.sub(originalString, string.find(originalString, a) + string.len(a), string.find(originalString, b, string.find(originalString, a) + string.len(a))-1)
    return  c
end
