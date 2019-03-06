-- Copyright 2019 BD7MQB (bd7mqb@qq.com)
-- This is free software, licensed under the GNU GENERAL PUBLIC LICENSE, Version 2

local nxo = require "nixio"
local util  = require("luci.util")
local nfs = require "nixio.fs"
local uci = require "luci.model.uci"
local json = require "luci.jsonc"
local os = os
local table = table
local string = string
local tonumber  = tonumber

module "luci.model.mmdvm"

function get_mmdvm_log()
	local logtxt
	local lines
	local cmd = "egrep -h \"from|end|watchdog|lost\" /var/log/mmdvm/MMDVM-%s.log | tail -n250" % {os.date("%Y-%m-%d")}
	logtxt = util.trim(util.exec(cmd))
	lines = util.split(logtxt, "\n")

	if #lines < 20 then
		cmd = "egrep -h \"from|end|watchdog|lost\" /var/log/mmdvm/MMDVM-%s.log | tail -n250" % {os.date("%Y-%m-%d", os.time()-24*60*60)}
		logtxt = logtxt .. "\n" .. util.trim(util.exec(cmd))

		lines = util.split(logtxt, "\n")
	end

	table.sort(lines, function(a,b) return a>b end)

	return lines
end

local function get_hearlist(loglines)
	local headlist = {}
	local duration, loss, ber, rssi
	-- local ts1duration, ts1loss, ts1ber, ts1rssi
	-- local ts2duration, ts2loss, ts2ber, ts2rssi
	-- local ysfduration, ysfloss, ysfber, ysfrssi
	-- local p25duration, p25loss, p25ber, p25rssi

	for i = 1, #loglines do
		local logline = loglines[i]
		-- remoing invaild lines
		repeat
			if string.find(logline, "BS_Dwn_Act") then
				break
			end
		until true
		repeat
			if string.find(logline, "invalid access") then
				break
			end
		until true
		repeat
			if string.find(logline, "received RF header for wrong repeater") then
				break
			end
		until true
		repeat
			if string.find(logline, "unable to decode the network CSBK") then
				break
			end
		until true
		repeat
			if string.find(logline, "overflow in the DMR slot RF queue") then
				break
			end
		until true
		repeat
			if string.find(logline, "non repeater RF header received") then
				break
			end
		until true
		repeat
			if string.find(logline, "Embedded Talker Alias") then
				break
			end
		until true
		repeat
			if string.find(logline, "DMR Talker Alias") then
				break
			end
		until true
		repeat
			if string.find(logline, "CSBK Preamble") then
				break
			end
		until true
		repeat
			if string.find(logline, "Preamble CSBK") then
				break
			end
		until true

		local mode = string.sub(logline, 28, string.find(logline, ",")-1)

		if string.find(logline, "end of") 
			or string.find(logline, "watchdog has expired")
			or string.find(logline, "ended RF data")
			or string.find(logline, "ended network")
			or string.find(logline, "RF user has timed out")
			or string.find(logline, "transmission lost")
		then
			local linetokens = util.split(logline, ", ")
			local count_tokens = (linetokens and #linetokens) or 0

			if string.find(logline, "RF user has timed out") then
				duration = "TOut"
				ber = "??"
			else
				if count_tokens >= 3 then
					duration = linetokens[3]
				end
				if count_tokens >= 4 then
					loss = linetokens[4]
				end
			end

			-- if RF-Packet, no LOSS would be reported, so BER is in LOSS position
			if string.find(loss, "BER") == 1 then
				ber = string.trim(string.sub(loss, 6))
				loss = "0"
				-- TODO: RSSI
			else
				loss = string.trim(string.sub(loss, 1, -14))
				if count_tokens >= 5 then
					ber = string.trim(string.sub(linetokens[5], 6, -2))
				end
			end

			-- table.insert(headlist, loss)
			-- table.insert(headlist, ber)
			-- table.insert(headlist, duration)

--[[]

			if string.find(logline, "ended RF data") or string.find(logline, "ended network") then
				if mode == "DMR Slot 1" then ts1duration = "SMS" 
				elseif mode == "DMR Slot 2" then ts2duration = "SMS" 
				end
			else
				local switch = {
					["DMR Slot 1"] = function()
						ts1duration = duration
						ts1loss = loss
						ts1ber = ber
						ts1rssi = rssi
					end,
					["DMR Slot 2"] = function()
						ts2duration = duration
						ts2loss = loss
						ts2ber = ber
						ts2rssi = rssi
					end,
					["YSF"] = function()
						ysfduration = duration
						ysfloss = loss
						ysfber = ber
						ysfrssi = rssi
					end,
					["P25"] = function()
						p25duration = duration
						p25loss = loss
						p25ber = ber
						p25rssi = rssi
					end
				}
				local f = switch[mode]
				if(f) then f() end
			end
 ]]

		end

		local timestamp = string.sub(logline, 4, 22)
		local callsign, target
		if string.find(logline, "from") then
			callsign = string.trim(string.sub(logline, string.find(logline, "from")+5, string.find(logline, "to") - 2))
			target = string.trim(string.sub(logline, string.find(logline, "to") + 3))
		end
		local source = "RF"
		if string.find(logline, "network") then
			source = "Net"
		end

		-- Callsign or ID should be less than 11 chars long, otherwise it could be errorneous
		if callsign and #callsign < 11 then
			table.insert(headlist, 
				{
					timestamp = timestamp, 
					mode = mode, 
					callsign = callsign, 
					target = target, 
					source = source,
					duration = duration,
					loss = tonumber(loss) or 0,
					ber = tonumber(ber) or 0,
					rssi = rssi
				}
			)
		end
	end -- end loop

	-- table.insert(headlist, 
	-- 	{
	-- 		timestamp = "timestamp", 
	-- 		mode = "mode", 
	-- 		callsign = "callsign", 
	-- 		target = "target", 
	-- 		source = "RF",
	-- 		duration = "duration",
	-- 		loss = tonumber(loss) or 0,
	-- 		ber = tonumber(ber) or 0,
	-- 		rssi = rssi
	-- 	}
	-- )
	return headlist
end

function get_lastheard()
	local lh = {}
	local calls = {}
	local loglines = get_mmdvm_log()
	local headlist = get_hearlist(loglines)

	for i = 1, #headlist, 1 do
		local key = headlist[i].callsign .. "@" .. headlist[i].mode
		
		if calls[key] == nil then
			calls[key] = true
			table.insert(lh, headlist[i])
		end

	end

	return lh
end