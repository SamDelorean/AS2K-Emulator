-- Directed wakeup acceptance for AS2K-DIAG only, NOT Stable/GTK.
-- Genuine HC11 firmware reacts to virtual PC cable; absolutely no key injection.
local machine=manager.machine
local screen=assert(machine.screens[":screen"], "AS2K LCD unavailable")
local port=assert(machine.ioport.ports[":PC_CONNECTED"], "patched DIAG PC_CONNECTED unavailable")
local field
for _,item in pairs(port.fields) do
    if item.mask==0x01 then field=item break end
end
assert(field, "PC_CONNECTED bit0 input unavailable")
local frame, failed = 0, false
local images={}
local function note(s)
    local f=assert(io.open("host-edge.events","a"))
    f:write("AS2K_DIAG_EDGE_",s,"\n")
    f:close()
end
local function shot(label)
    local pix,w,h=screen:pixels()
    assert(pix and w==240 and h==36, "LCD geometry mismatch")
    images[label]=pix
    local err=screen:snapshot(label..".png")
    assert(not err, "internal MAME screenshot failed")
    note("SNAP_"..label)
end
local function pixels_changed(a,b)
    local x,y=assert(images[a]),assert(images[b])
    assert(#x==#y)
    local count=0
    for i=1,#x do
        if x:byte(i)~=y:byte(i) then count=count+1 end
    end
    return count
end
local function cable(connected)
    field:set_value(connected and 1 or 0)
    note(connected and "PC_ON_SET" or "PC_OFF_SET")
end
local function readback(label,expected)
    local val=port:read() & 1
    note("PORT_"..label.."_"..tostring(val))
    assert(val==expected,"PC port wrong after "..label)
end
emu.register_frame_done(function()
    if failed or frame>=1220 then return end
    local ok,err=pcall(function()
        frame=frame+1
        if frame==540 then shot("before") end  -- 10.8 emulated seconds
        if frame==600 then cable(true) end
        if frame==615 then readback("ATTACHED",1) end
        if frame==690 then field:set_value(1);note("DUPLICATE_PC_ON") end
        if frame==800 then shot("attached") end
        if frame==870 then cable(false) end
        if frame==885 then readback("DETACHED",0) end
        if frame==965 then field:set_value(0);note("DUPLICATE_PC_OFF") end
        if frame==1080 then shot("after") end
        if frame==1180 then
            note("PIXEL_DELTA_BEFORE_ATTACHED_"..pixels_changed("before","attached"))
            note("PIXEL_DELTA_ATTACHED_AFTER_"..pixels_changed("attached","after"))
            note("NO_KEY_INJECTION")
            note("OBSERVATION_COMPLETE")
        end
    end)
    if not ok then
        failed=true
        note("OBSERVATION_FAILED_"..tostring(err):gsub("[\r\n]"," "))
        pcall(function()field:set_value(0)end)
    end
end)
note("LUA_ATTACHED")
