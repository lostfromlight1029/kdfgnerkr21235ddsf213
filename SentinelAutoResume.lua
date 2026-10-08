local H,P=game:GetService("HttpService"),game:GetService("Players")
local F,S="sentinel/last_path_resume","sentinel/last_path_resume/state.json"

local function mkdir(p)
	if type(makefolder)~="function" then return end
	if type(isfolder)~="function" or not isfolder(p) then pcall(makefolder,p) end
end

local function write(s)
	if type(writefile)~="function" then return end
	mkdir("sentinel");mkdir(F)
	local ok,j=pcall(H.JSONEncode,H,{enabled=s.enabled==true,path=s.path or "",active=s.active==true,expectedTeleport=s.expectedTeleport==true})
	if ok then pcall(writefile,S,j) end
end

local function read()
	local d={enabled=false,path="",active=false,expectedTeleport=false}
	if type(isfile)~="function" or type(readfile)~="function" or not isfile(S) then return d end
	local ok,r=pcall(readfile,S)
	if not ok then return d end
	ok,r=pcall(H.JSONDecode,H,r)
	if not ok or type(r)~="table" then return d end
	d.enabled=r.enabled==true;d.path=type(r.path)=="string" and r.path or "";d.active=r.active==true;d.expectedTeleport=r.expectedTeleport==true
	return d
end

local state=read()
write(state)
local target=state.enabled and state.active and state.path~="" and state.path or nil
local locked=target~=nil

local function getLibrary()
	while true do
		local e=getgenv and getgenv()
		local l=e and rawget(e,"Library")
		if l and l.Options and l.Options.SavedPaths and l.Options.PathName and l.Tabs and l.Tabs.Botting and l.ScreenGui and l.ScreenGui.Parent then return l end
		task.wait(.2)
	end
end

local L=getLibrary()
L.Tabs.Botting:AddRightGroupbox("Path Resume"):AddToggle("LastPathAutoResume",{
	Text="Auto Resume",Default=state.enabled,
	Callback=function(v)
		state.enabled=v==true
		if not state.enabled then state.active=false;state.expectedTeleport=false;target=nil;locked=false end
		write(state)
	end
})

local function findButton(text)
	while L.ScreenGui and L.ScreenGui.Parent do
		for _,v in ipairs(L.ScreenGui:GetDescendants()) do if v:IsA("TextButton") and v.Text==text then return v end end
		task.wait(.2)
	end
	return nil
end

local Start,Stop=findButton("Start Path"),findButton("Stop Bot")
local function holder(b)
	local v=b and b.Parent
	while v and v~=L.ScreenGui do if v:IsA("Frame") and v.Name=="Button" then return v end;v=v.Parent end
	return b and b.Parent and b.Parent.Parent
end
local StopHolder=holder(Stop)

local function fire(s,play)
	if not s then return false end
	local fired=false
	if play and type(replicatesignal)=="function" then fired=pcall(replicatesignal,s) end
	if type(firesignal)=="function" and pcall(firesignal,s) then return true end
	if fired then return true end
	if type(getconnections)~="function" then return false end
	local ok,c=pcall(getconnections,s)
	if not ok or type(c)~="table" then return false end
	for _,x in ipairs(c) do
		if type(x.Fire)=="function" then pcall(x.Fire,x);fired=true
		elseif type(x.Function)=="function" then pcall(x.Function);fired=true end
	end
	return fired
end

local function current()
	local p=L.Options.PathName.Value
	if type(p)=="string" and p~="" then return p end
	p=L.Options.SavedPaths.Value
	return type(p)=="string" and p~="" and p or (state.path~="" and state.path or nil)
end

local function running()
	return StopHolder and StopHolder.Parent and StopHolder.Visible==true or false
end

local function set(active,path)
	if path and path~="" then state.path=path end
	state.active=active
	if not active then state.expectedTeleport=false end
	write(state)
end

local function remember(path)
	if state.enabled and not locked and type(path)=="string" and path~="" then state.path=path;write(state) end
end

if type(L.Options.PathName.OnChanged)=="function" then L.Options.PathName:OnChanged(remember) end
if type(L.Options.SavedPaths.OnChanged)=="function" then
	L.Options.SavedPaths:OnChanged(function(v)
		if locked or not state.enabled then return end
		task.delay(.2,function() if type(v)=="string" and v~="" then remember(current()) end end)
	end)
end

if Start then Start.MouseButton1Click:Connect(function()
	task.delay(.35,function() if state.enabled and running() then set(true,locked and target or current()) end end)
end) end

if Stop then Stop.MouseButton1Click:Connect(function()
	task.delay(.05,function() locked=false;target=nil;set(false,current()) end)
end) end

P.LocalPlayer.OnTeleport:Connect(function(t)
	if not state.enabled or not state.active then return end
	if t==Enum.TeleportState.Started or t==Enum.TeleportState.WaitingForServer or t==Enum.TeleportState.InProgress then state.expectedTeleport=true;write(state)
	elseif t==Enum.TeleportState.Failed then state.expectedTeleport=false;write(state) end
end)

if state.enabled and running() then state.expectedTeleport=false;set(true,current()) end

task.spawn(function()
	local was=running()
	while L.ScreenGui and L.ScreenGui.Parent do
		local now=running()
		if state.enabled and now and not was then state.expectedTeleport=false;set(true,locked and target or current()) end
		was=now;task.wait(.2)
	end
end)

local function character(timeout)
	local deadline=os.clock()+timeout
	repeat
		local c=P.LocalPlayer.Character
		local h=c and c:FindFirstChildOfClass("Humanoid")
		if c and h and h.Health>0 and c:FindFirstChild("HumanoidRootPart") then return true end
		task.wait(.25)
	until os.clock()>=deadline
	return false
end

local function play()
	if character(.25) then return true end
	local g=P.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not g then return false end
	local m=g:FindFirstChild("StartMenu") or g:WaitForChild("StartMenu",45)
	if not m then return false end
	local deadline=os.clock()+30
	while state.enabled and os.clock()<deadline and not character(.05) do
		local c=m:FindFirstChild("Choices")
		local b=c and c:FindFirstChild("Play")
		if b then fire(b.MouseButton1Click,true) end
		task.wait(.5)
	end
	return state.enabled and character(15)
end

local function selectPath(path,timeout)
	if not state.enabled or not path or path=="" or type(L.Options.SavedPaths.SetValue)~="function" then return false end
	local deadline,stable=os.clock()+timeout,0
	while state.enabled and os.clock()<deadline do
		if L.Options.PathName.Value~=path or L.Options.SavedPaths.Value~=path then
			pcall(L.Options.SavedPaths.SetValue,L.Options.SavedPaths,path);stable=0
		else
			stable+=.2
			if stable>=1.5 then return true end
		end
		task.wait(.2)
	end
	return state.enabled and L.Options.PathName.Value==path
end

if target then task.spawn(function()
	if running() or not state.enabled then locked=false;return end

	if state.expectedTeleport then
		local deadline=os.clock()+15
		while state.enabled and os.clock()<deadline and not running() do task.wait(.25) end
		if running() then state.expectedTeleport=false;write(state);locked=false;target=nil;return end
	else
		task.wait(3)
	end

	state.expectedTeleport=false;write(state)
	if not selectPath(target,10) or not play() then return end
	task.wait(1)
	if not selectPath(target,5) then return end
	set(true,target)
	if not running() and Start then fire(Start.MouseButton1Click) end

	local deadline=os.clock()+8
	while state.enabled and os.clock()<deadline and not running() do
		if L.Options.PathName.Value~=target then selectPath(target,2) end
		task.wait(.2)
	end
	if running() then set(true,target);locked=false;target=nil end
end) end
