-- AS2K-DIAG exclusive: true printer PA0 then PC PA0+PA2, each with
-- one HC11 IRQ per attach/detach. Never inject any keyboard key.
-- PC is included as a directed no-regression check, not another Send test.
local m=manager.machine
local screen=assert(m.screens[":screen"],"AS2K LCD missing")
local ports=m.ioport.ports
local function field(tag)
    local p=assert(ports[":"..tag],tag.." diagnostic input missing")
    for _,f in pairs(p.fields) do
        if f.mask==1 then return p,f end
    end
    error(tag.." bit0 diagnostic field missing")
end
local printer_port,printer=field("PRINTER_CONNECTED")
local pc_port,pc=field("PC_CONNECTED")
local frame,failed=0,false
local pixels={}
local function event(name)
    local f=assert(io.open("printer-host.events","a"))
    f:write("AS2K_DIAG_HOST_",name,"\n")
    f:close()
end
local function snap(name)
    local img,w,h=screen:pixels()
    assert(img and w==240 and h==36,"LCD geometry mismatch")
    pixels[name]=img
    local err=screen:snapshot(name..".png")
    assert(not err,"screen snapshot failed")
    event("SNAP_"..name)
end
local function delta(a,b)
    local x,y=assert(pixels[a]),assert(pixels[b])
    assert(#x==#y,"pixel image length mismatch")
    local n=0
    for i=1,#x do if x:byte(i)~=y:byte(i) then n=n+1 end end
    return n
end
local function set(target,connected)
    target:set_value(connected and 1 or 0)
end
local function check(name,p,want)
    local v=p:read() & 1
    event("PORT_"..name.."_"..tostring(v))
    assert(v==want,"wrong port state "..name)
end
local function tick()
    frame=frame+1
    if frame==540 then snap("editor_before") end
    if frame==600 then set(printer,true);event("PRINTER_ON") end
    if frame==615 then check("PRINTER_ON",printer_port,1);check("PC_STAYS_OFF",pc_port,0) end
    if frame==680 then set(printer,true);event("PRINTER_ON_REPEAT") end
    if frame==760 then snap("printer_attached") end
    if frame==820 then set(printer,false);event("PRINTER_OFF") end
    if frame==835 then check("PRINTER_OFF",printer_port,0) end
    if frame==900 then set(printer,false);event("PRINTER_OFF_REPEAT") end
    if frame==960 then snap("printer_detached") end
    if frame==1020 then set(pc,true);event("PC_ON") end
    if frame==1035 then check("PC_ON",pc_port,1);check("PRINTER_STAYS_OFF",printer_port,0) end
    if frame==1100 then set(pc,true);event("PC_ON_REPEAT") end
    if frame==1160 then snap("pc_attached") end
    if frame==1220 then set(pc,false);event("PC_OFF") end
    if frame==1235 then check("PC_OFF",pc_port,0) end
    if frame==1310 then set(pc,false);event("PC_OFF_REPEAT") end
    if frame==1360 then snap("pc_detached") end
    if frame==1430 then
        event("LCD_PRINTER_DELTA_"..delta("editor_before","printer_attached"))
        event("LCD_PRINTER_RETURN_DELTA_"..delta("editor_before","printer_detached"))
        event("LCD_PC_DELTA_"..delta("editor_before","pc_attached"))
        event("LCD_PC_RETURN_DELTA_"..delta("editor_before","pc_detached"))
        event("NO_KEYS_INJECTED")
        event("OBSERVATION_COMPLETE")
    end
end
emu.register_frame_done(function()
    if failed or frame>=1440 then return end
    local ok,err=pcall(tick)
    if not ok then
        failed=true
        event("OBSERVATION_FAILED_"..tostring(err):gsub("[\r\n]"," "))
        pcall(function()printer:set_value(0);pc:set_value(0)end)
    end
end)
event("LUA_ATTACHED")
