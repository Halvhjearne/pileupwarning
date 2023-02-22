--[[
------------------------------------------------------------------
| pileupwarning                                                  |
| lua app for warning about stopped traffic in ac by Halvhjearne |
------------------------------------------------------------------
| this is a free app and may not be used in any commercial       |
| way without written permission from Halvhjearne                |
------------------------------------------------------------------
--]]

local playercar = ac.getCar(0)
local sim = ac.getSim()

local pileupsettings = {
    minspeed = 40,
    mindist = 0,
    signsize = 100,
    maxdist = 1500,
    playermaxcount = 2,
    playermaxdist = 150,
    angle = 90,
    mincars = 2,
    alwaysshowwarning = false,
    debug = false
}

local savetxt = ''
local dir = ac.getFolder(ac.FolderID.ExtCfgUser)..'/pileupwarning/'
local mapini = ac.getFolder(ac.FolderID.ContentTracks) .. '/' .. ac.getTrackFullID('/') .. '/data/map.ini'
local scale = 1
if io.fileExists(mapini) then
    local data = ac.INIConfig.load(mapini)
    scale = data:get('PARAMETERS','SCALE_FACTOR',1)
end

local defaultsfilename = dir..'/defaults.cfg'
local filename = dir..ac.getTrackFullID('/')..'.cfg'

if io.fileExists(mapini) then
    local data = ac.INIConfig.load(mapini)
    scale = data:get('PARAMETERS','SCALE_FACTOR',1)
end

local loadfile = ''
if io.fileExists(filename) then
    loadfile = filename
elseif io.fileExists(defaultsfilename) then
    loadfile = defaultsfilename
end

if loadfile ~= '' then
    local data = ac.INIConfig.load(loadfile)
    for k,v in pairs(pileupsettings) do
        pileupsettings[k] = data:get('DEFAULTS', k, v)
    end
end

local function checkIsPlayerNearby(pos)
    local isnearby = 0
    for i = 1, sim.carsCount - 1 do
        if isnearby > pileupsettings.playermaxcount then
            isnearby = pileupsettings.playermaxcount
            break
        end
        local car = ac.getCar(i)
        if car.isConnected and (not car.isHidingLabels) then
            local distancefromme = (car.position:distance(pos))*scale
            if distancefromme <= pileupsettings.playermaxdist then
                isnearby =  isnearby + 1
            end
        end
    end
    return isnearby
end

local function checkdir(spos, sdir, tpos)
--    local dirtot = math.atan((target.position.y - source.position.y), (target.position.x - source.position.x))*(180 / math.pi)
    local dirtot = ac.getCompassAngle(vec3(tpos.x - spos.x,tpos.y - spos.y,tpos.z - spos.z))
    local returnval = dirtot-sdir
    if returnval > 180 then
        returnval = returnval-360
    elseif returnval < 180*-1 then
        returnval = returnval+360
    end
    local isfront = true
    if returnval > pileupsettings.angle or returnval < pileupsettings.angle*-1 then
        isfront =  false
    end
    return isfront, dirtot, returnval
end

local function fncsetnsave(savefile)
    local data = ac.INIConfig.load(savefile)
    if io.fileExists(savefile) then
        io.deleteFile(savefile)
        data = ac.INIConfig.load(savefile)
    else
        if not io.dirExists(dir) then
            io.createDir(dir)
        end
    end
    for k,v in pairs(pileupsettings) do
        if k ~= 'debug' then
            data:setAndSave('DEFAULTS', k, v)
        end
    end
    local txt = 'Default Settings saved'
    if defaultsfilename ~= savefile then
        txt = 'Settings saved for '..ac.getTrackName()
    end
    return txt
end

local function warningcheck()
    local showwarning = false
    if pileupsettings.alwaysshowwarning then showwarning = true end
    local num = 0
    local mycar = playercar
    if sim.focusedCar > 0 then
        mycar = ac.getCar(sim.focusedCar)
    end
    for i = 1, sim.carsCount - 1 do
        local car = ac.getCar(i)
        -- isRemote ?
        if (car.isHidingLabels or car.isAIControlled) and car.isConnected then
            local distancefromme = car.position:distance(mycar.position)*scale
            local infront, dirtot, returnval = checkdir(mycar.position,mycar.compass,car.position)
            if pileupsettings.debug then
                ui.bulletText('car: '..i..' - Km/h: '..math.floor(car.speedKmh)..' - Dir to car: '..math.floor(dirtot)..' - returnval: '..math.floor(returnval)..' - infront: '..tostring(infront)..' - Distance: '..math.floor(distancefromme))
            end
            if infront and car.speedKmh <= pileupsettings.minspeed and distancefromme >= pileupsettings.mindist and distancefromme <= pileupsettings.maxdist then
                if pileupsettings.debug then ui.sameLine(0,5) ui.text(' - (triggered)') end

                num = num + 1
                local check = num
                if pileupsettings.playermaxcount > 0 and num > 0 then
                    local extra = checkIsPlayerNearby(car.position)
                    if extra > 0 then
                        check = check + extra
                    end
                end
                if check >= pileupsettings.mincars then
                    showwarning = true
                    if not pileupsettings.debug then
                        break
                    end
                end
            end
        end
    end
    return showwarning
end

function script.pileupwarning(dt)
    if warningcheck() then
        ui.image('pileup.png',vec2(pileupsettings.signsize,pileupsettings.signsize))
    end
end

function script.pileupwarningMain(dt)
    ui.icon('pileup.png', vec2(15,15), rgbm(1, 1, 1, 1))
    ui.sameLine(0, 5)
    ui.header('Settings:')
    ui.separator()
    pileupsettings.minspeed = ui.slider('Min speed', pileupsettings.minspeed, 0, 200, '%.0fKm/h')
    if ui.itemHovered() then ui.setTooltip('Speeds above this can not trigger the warning') end
    pileupsettings.mindist = ui.slider('Min distance', pileupsettings.mindist, 0, pileupsettings.maxdist-1, '%.0fm')
    if ui.itemHovered() then ui.setTooltip('Distance below this can not trigger the warning') end
    pileupsettings.maxdist = ui.slider('Max distance', pileupsettings.maxdist, pileupsettings.mindist+1, 10000, '%.0fm')
    if ui.itemHovered() then ui.setTooltip('Distance above this can not trigger the warning') end
    pileupsettings.angle = ui.slider('Angle', pileupsettings.angle, 0, 180, '%.0f')
    if ui.itemHovered() then ui.setTooltip('Angles around the cars gps direction (both sides), where ai can trigger the warning') end

    pileupsettings.mincars = ui.slider('Min cars', pileupsettings.mincars, 0, 100, '%.0f')
    if ui.itemHovered() then ui.setTooltip('Minimum amount of cars to be triggered, before the warning will be triggered') end
    ui.separator()
    pileupsettings.playermaxdist = ui.slider('Player distance', pileupsettings.playermaxdist, 0, pileupsettings.maxdist, '%.0fm')
    if ui.itemHovered() then ui.setTooltip('Player(s) within this distance will also be countet in min cars') end
    local pmax = pileupsettings.mincars-1
    if pmax < 0 then
        pmax = 0
    end
    if pileupsettings.playermaxcount > pmax then
        pileupsettings.playermaxcount = pmax
    end
    pileupsettings.playermaxcount = ui.slider('Max player(s)', pileupsettings.playermaxcount, 0, pmax, '%.0f')
    if ui.itemHovered() then ui.setTooltip('Maximum amount of players to add to min cars near a slowing ai') end
    ui.separator()
    pileupsettings.signsize = ui.slider('Warning size', pileupsettings.signsize, 25, 500, '%.0fx'..pileupsettings.signsize)
    if ui.itemHovered() then ui.setTooltip('Size of the warning sign') end
    if ui.checkbox('Always show warning', pileupsettings.alwaysshowwarning) then
        if ui.keyboardButtonDown(ui.KeyIndex.Control) and ui.keyboardButtonDown(ui.KeyIndex.Shift) then
            pileupsettings.debug = not pileupsettings.debug
        else
            pileupsettings.alwaysshowwarning = not pileupsettings.alwaysshowwarning
        end
    end
    if ui.itemHovered() then ui.setTooltip('Always shows warning to see and place it on the screen') end
    ui.separator()
    if pileupsettings.debug then
        local mycar = playercar
        if sim.focusedCar > 0 then
            mycar = ac.getCar(sim.focusedCar)
        end
        local t = {
            ['sim.focusedCar: '] = sim.focusedCar,
            ['car compass: '] = math.floor(mycar.compass),
            ['car pos: '] = tostring(mycar.position),
            ['car speed: '] = math.floor(mycar.speedKmh),
            ['cam pos: '] = tostring(ac.getCameraPosition()),
            ['map scale: '] = tostring(scale),
            ['cam compass: '] = math.floor(ac.getCompassAngle(ac.getCameraForward()))
        }
        for key, value in pairs(t) do
            ui.bulletText(key..value)
        end
    end
    if ui.button('Save track settings') then
        savetxt = fncsetnsave(filename)
    end
    if ui.button('Save default settings') then
        savetxt = fncsetnsave(defaultsfilename)
    end
    ui.separator()
    ui.labelText(savetxt,'* pileupwarning by Halvhjearne!')
    if ui.itemHovered() then savetxt = '' end
end

--function script.update(dt)
--    ac.setMessage('test','test test')
--end
