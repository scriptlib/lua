--[[

	Clock: a simple in-game clock window
		copyright 2004 by Telo

	- Displays the time in a small, movable window
	- Displays time-based character information in a tooltip on mouseover

]]

--------------------------------------------------------------------------------------------------
-- Localizable strings
--------------------------------------------------------------------------------------------------

CLOCK = "Clock";
BINDING_NAME_TOGGLECLOCK = "Toggle Clock";

CLOCK_HELP = "help";			-- must be lowercase; displays help
CLOCK_STATUS = "status";		-- must be lowercase; shows status
CLOCK_FREEZE = "freeze";		-- must be lowercase; freezes the clock in position
CLOCK_UNFREEZE = "unfreeze";	-- must be lowercase; unfreezes the clock so that it can be dragged
CLOCK_RESET = "reset";			-- must be lowercase; resets the clock to its default position
CLOCK_24_HOUR = "24-hour";		-- must be lowercase; sets the clock to 24 hour time display
CLOCK_12_HOUR = "12-hour";		-- must be lowercase; sets the clock to 12 hour time display

CLOCK_STATUS_HEADER = "|cffffff00Clock status:|r";
CLOCK_FROZEN = "Clock:锁定位置";
CLOCK_UNFROZEN = "Clock: 解锁,使可被拖动";
CLOCK_RESET_DONE = "Clock: 重置于默认位置";
CLOCK_SET_24 = "Clock: 24小时制";
CLOCK_SET_12 = "Clock: 12小时制";
CLOCK_TIME_OFFSET = "Clock: displayed time is offset by %s%02d:%02d";
CLOCK_TIME_ERROR = "Clock: unable to determine a valid offset from that input";

CLOCK_HELP_TEXT0 = " ";
CLOCK_HELP_TEXT1 = "|cffffff00Clock 命令行帮助:|r";
CLOCK_HELP_TEXT2 = "|cff00ff00使用 |r|cffffffff/clock <command>|r|cff00ff00 于以下数种参数:|r";
CLOCK_HELP_TEXT3 = "|cffffffff"..CLOCK_HELP.."|r|cff00ff00: 显示此帮助.|r";
CLOCK_HELP_TEXT4 = "|cffffffff"..CLOCK_STATUS.."|r|cff00ff00: 显示当前状态及设定.|r";
CLOCK_HELP_TEXT5 = "|cffffffff"..CLOCK_FREEZE.."|r|cff00ff00: 锁定位置.|r";
CLOCK_HELP_TEXT6 = "|cffffffff"..CLOCK_UNFREEZE.."|r|cff00ff00: 解锁,使可被拖动.|r";
CLOCK_HELP_TEXT7 = "|cffffffff"..CLOCK_RESET.."|r|cff00ff00: 重置于默认位置.|r";
CLOCK_HELP_TEXT8 = "|cffffffff"..CLOCK_24_HOUR.."|r|cff00ff00: 以24小时制显示.|r";
CLOCK_HELP_TEXT9 = "|cffffffff"..CLOCK_12_HOUR.."|r|cff00ff00: 以12小时制显示.|r";
CLOCK_HELP_TEXT10 = "|cff00ff00此外的命令参数将被作为相对于服务器时间的调整.|r";
CLOCK_HELP_TEXT11 = "|cff00ff00支持的格式包括 -:30, +11, 5:30, 0, 等等.|r";
CLOCK_HELP_TEXT12 = " ";
CLOCK_HELP_TEXT13 = "|cff00ff00例如: |r|cffffffff/clock +2|r|cff00ff00 将使时钟显示的时间晚于服务器时间2小时.|r";

--------------------------------------------------------------------------------------------------
-- Local variables
--------------------------------------------------------------------------------------------------


local lBeingDragged;
-- the current server
local lServer;

--------------------------------------------------------------------------------------------------
-- Global variables
--------------------------------------------------------------------------------------------------

-- Constants
CLOCK_UPDATE_RATE = 0.1;

--------------------------------------------------------------------------------------------------
-- Internal functions
--------------------------------------------------------------------------------------------------

local function Clock_Status()
	DEFAULT_CHAT_FRAME:AddMessage(CLOCK_STATUS_HEADER);
	if( ClockState ) then
		if( ClockState.Freeze ) then
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_FROZEN);
		else
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_UNFROZEN);
		end
		if( ClockState.MilitaryTime ) then
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_SET_24);
		else
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_SET_12);
		end
		local hour;
		local minute;
		local sign;
		if( ClockState.Servers[lServer].OffsetHour ) then
			hour = ClockState.Servers[lServer].OffsetHour;
		else
			hour = 0;
		end
		if( ClockState.Servers[lServer].OffsetMinute ) then
			minute = ClockState.Servers[lServer].OffsetMinute;
		else
			minute = 0;
		end
		if( hour < 0 or minute < 0 ) then
			sign = "-";
		else
			sign = "+";
		end
		DEFAULT_CHAT_FRAME:AddMessage(format(CLOCK_TIME_OFFSET, sign, hour, minute));
	else
		DEFAULT_CHAT_FRAME:AddMessage(CLOCK_UNFROZEN);
		DEFAULT_CHAT_FRAME:AddMessage(CLOCK_SET_12);
		DEFAULT_CHAT_FRAME:AddMessage(format(CLOCK_TIME_OFFSET, "+", 0, 0));
	end
end

local function Clock_Reset()
	ClockFrame:ClearAllPoints();
	ClockFrame:SetPoint("TOP", "UIParent", "TOP", 0, 0);
end

function Clock_SlashCommandHandler(msg)
	if( msg ) then
		local command = string.lower(msg);
		if( command == "" or command == CLOCK_HELP ) then
			local index = 0;
			local value = getglobal("CLOCK_HELP_TEXT"..index);
			while( value ) do
				DEFAULT_CHAT_FRAME:AddMessage(value);
				index = index + 1;
				value = getglobal("CLOCK_HELP_TEXT"..index);
			end
		elseif( command == CLOCK_STATUS ) then
			Clock_Status();
		elseif( command == CLOCK_FREEZE ) then
			ClockState.Freeze = 1;
			Clock_OnDragStop();
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_FROZEN);
		elseif( command == CLOCK_UNFREEZE ) then
			ClockState.Freeze = nil;
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_UNFROZEN);
		elseif( command == CLOCK_RESET ) then
			Clock_Reset();
			Clock_OnDragStop();
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_RESET_DONE);
		elseif( command == CLOCK_24_HOUR ) then
			ClockState.MilitaryTime = 1;
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_SET_24);
		elseif( command == CLOCK_12_HOUR ) then
			ClockState.MilitaryTime = nil;
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_SET_12);
		else
			local s, e, sign, hour, minute = string.find(command, "^([+-]?)(%d*):?(%d*)$");
			if( hour or minute ) then
				if( not hour or hour == "" ) then
					hour = 0;
				end
				if( not minute or minute == "" ) then
					minute = 0;
				end
				if( string.len(hour) <= 2 and string.len(minute) <= 2 ) then
					if( sign and sign == "-" ) then
						ClockState.Servers[lServer].OffsetHour = -(hour + 0);
						ClockState.Servers[lServer].OffsetMinute = -(minute + 0);
					else
						sign = "+";
						ClockState.Servers[lServer].OffsetHour = hour + 0;
						ClockState.Servers[lServer].OffsetMinute = minute + 0;
					end
					DEFAULT_CHAT_FRAME:AddMessage(format(CLOCK_TIME_OFFSET, sign, hour, minute));
					return;
				end
			end
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_TIME_ERROR);
		end
	end
end


local function Clock_ParsePosition(position)
	local x, y, z;
	local iStart, iEnd;

	iStart, iEnd, x, y, z = string.find(position, "^(.-), (.-), (.-)$");
	if( z ) then
		return x + 0.0, y + 0.0, z + 0.0;
	end
	return nil, nil, nil;
end

--------------------------------------------------------------------------------------------------
-- OnFoo functions
--------------------------------------------------------------------------------------------------

function Clock_OnLoad()
	this:RegisterForDrag("LeftButton");

	RegisterForSave("ClockState");

	-- Register our slash command
	SLASH_CLOCK1 = "/clock";
	SlashCmdList["CLOCK"] = function(msg)
		Clock_SlashCommandHandler(msg);
	end
	
	this:RegisterEvent("VARIABLES_LOADED");
		
	ClockFrame.TimeSinceLastUpdate = 0;

	if( DEFAULT_CHAT_FRAME ) then
		DEFAULT_CHAT_FRAME:AddMessage("Telo's Clock AddOn loaded");
	end
	UIErrorsFrame:AddMessage("Telo's Clock AddOn loaded", 1.0, 1.0, 1.0, 1.0, UIERRORS_HOLD_TIME);
end

function Clock_OnUpdate(arg1)

	ClockFrame.TimeSinceLastUpdate = ClockFrame.TimeSinceLastUpdate + arg1;
	if( ClockFrame.TimeSinceLastUpdate > CLOCK_UPDATE_RATE ) then
		ClockText:SetText(Clock_GetTimeText());
		ClockFrame.TimeSinceLastUpdate = 0;
	end
end

function Clock_OnEvent()
	if( event == "VARIABLES_LOADED" ) then
		if( not ClockState ) then
			ClockState = { };
		end
		if( not ClockState.Servers ) then
			ClockState.Servers = { };
		end

		lServer = GetCVar("realmName");
		if( not ClockState.Servers[lServer] ) then
			ClockState.Servers[lServer] = { };
		end
		
			-- Convert old global time offset data into data for the current server
		if( ClockState.OffsetHour or ClockState.OffsetMinute ) then
			ClockState.Servers[lServer].OffsetHour = ClockState.OffsetHour;
			ClockState.Servers[lServer].OffsetMinute = ClockState.OffsetMinute;
			ClockState.OffsetHour = nil;
			ClockState.OffsetMinute = nil;
		end
	end
end

function ClockText_OnEnter()
	GameTooltip:SetOwner(ClockFrame, "ANCHOR_NONE");
	GameTooltip:SetPoint("TOP", "UIParent", "TOP", 0, -32);
end

function Clock_OnDragStart()
	if( not ClockState or not ClockState.Freeze ) then
		ClockFrame:StartMoving()
		lBeingDragged = 1;
	end
end

function Clock_OnDragStop()
	ClockFrame:StopMovingOrSizing()
	lBeingDragged = nil;
end

-- Helper functions
function Clock_GetTimeText()
	local hour, minute = GetGameTime();
	local pm;
	
	if( ClockState ) then
		if( ClockState.Servers[lServer].OffsetHour ) then
			hour = hour + ClockState.Servers[lServer].OffsetHour;
		end
		if( ClockState.Servers[lServer].OffsetMinute ) then
			minute = minute + ClockState.Servers[lServer].OffsetMinute;
		end
	end
	if( minute > 59 ) then
		minute = minute - 60;
		hour = hour + 1
	elseif( minute < 0 ) then
		minute = 60 + minute;
		hour = hour - 1;
	end
	if( hour > 23 ) then
		hour = hour - 24;
	elseif( hour < 0 ) then
		hour = 24 + hour;
	end
	
	if( ClockState and ClockState.MilitaryTime ) then
		return format(TEXT(TIME_TWENTYFOURHOURS), hour, minute);
	else
		if( hour >= 12 ) then
			pm = 1;
			hour = hour - 12;
		else
			pm = 0;
		end
		if( hour == 0 ) then
			hour = 12;
		end
		if( pm == 1 ) then
			return format(TEXT(TIME_TWELVEHOURPM), hour, minute);
		else
			return format(TEXT(TIME_TWELVEHOURAM), hour, minute);
		end
	end
end

