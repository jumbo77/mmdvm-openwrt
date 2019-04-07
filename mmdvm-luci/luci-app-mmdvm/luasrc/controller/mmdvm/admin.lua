-- Copyright 2019 BD7MQB <bd7mqb@qq.com>
-- This is free software, licensed under the GNU GENERAL PUBLIC LICENSE, Version 2.0

module("luci.controller.mmdvm.admin", package.seeall)

local sys   = require("luci.sys")
local util  = require("luci.util")
local http  = require("luci.http")
local i18n  = require("luci.i18n")
local json  = require("luci.jsonc")
local uci   = require("luci.model.uci").cursor()

function index()
	if not nixio.fs.access("/etc/MMDVM.ini") then
		return
	end
	entry({"admin", "mmdvm"}, firstchild(), _("MMDVM"), 30).dependent = false
	entry({"admin", "mmdvm", "config"}, firstchild(), _("Configuration"), 40).index = true
	entry({"admin", "mmdvm", "config", "general"}, cbi("mmdvm/config_general"), _("General"), 41)
	entry({"admin", "mmdvm", "config", "dvmode"}, cbi("mmdvm/config_dvmode"), _("Digital Modes"), 42)
	entry({"admin", "mmdvm", "advanced"}, firstchild(), _("Advanced"), 100)
	entry({"admin", "mmdvm", "advanced", "mmdvmhost"}, form("mmdvm/mmdvmhost_tab"), _("MMDVMHost"), 110).leaf = true
	entry({"admin", "mmdvm", "advanced", "ysfgateway"}, form("mmdvm/ysfgateway_tab"), _("YSFGateway"), 120).leaf = true
	entry({"admin", "mmdvm", "advanced", "p25gateway"}, form("mmdvm/p25gateway_tab"), _("P25Gateway"), 130).leaf = true
	entry({"admin", "mmdvm", "advanced", "nxdngateway"}, form("mmdvm/nxdngateway_tab"), _("NXDNGateway"), 140).leaf = true
	-- dapnetgateway is optional 
	if nixio.fs.access("/etc/init.d/dapnetgateway") then
		entry({"admin", "mmdvm", "advanced", "dapnetgateway"}, form("mmdvm/dapnetgateway_tab"), _("DAPNETGateway"), 150).leaf = true	
	end
	entry({"admin", "mmdvm", "log"}, firstchild(), _("Live Log"), 999)
	entry({"admin", "mmdvm", "log", "mmdvmhost"}, call("action_livelog", {title="MMDVMHost", log="host"}), "MMDVMHost", 21).leaf = true
	entry({"admin", "mmdvm", "log", "p25"}, call("action_livelog", {title="P25Gateway", log="p25"}), "P25Gateway", 22).leaf = true
	entry({"admin", "mmdvm", "log", "ysf"}, call("action_livelog", {title="YSFGateway", log="ysf"}), "YSFGateway", 23).leaf = true
	entry({"admin", "mmdvm", "log", "nxdn"}, call("action_livelog", {title="NXDNGateway", log="nxdn"}), "NXDNGateway", 24).leaf = true
	if nixio.fs.access("/etc/init.d/dapnetgateway") then
		entry({"admin", "mmdvm", "log", "dapnet"}, call("action_livelog", {title="DAPNETGateway", log="dapnet"}), "DAPNETGateway", 25).leaf = true
	end
end

function action_livelog(argv)
	luci.template.render("mmdvm/logread", argv)
end