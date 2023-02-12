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

local pileupsettings = ac.storage{
    minspeed = 40,
    mindist = 0,
    signsize = 100,
    maxdist = 1250,
    playermaxdist = 50,
    angle = 90,
    mincars = 2,
    playernearby = false,
    includeself = false,
    alwaysshowwarning = false,
    debug = false
}

local function checkIsPlayerNearby(pos)
    local isnearby = false
    local num = 1
    if pileupsettings.includeself then
        num = 0
    end
    for i = num, sim.carsCount - 1 do
        local car = ac.getCar(i)
        if car.isConnected and (not car.isHidingLabels) then
            local distancefromme = car.position:distance(pos)
            if distancefromme <= pileupsettings.playermaxdist then
                isnearby =  true
                break
            end
        end
    end
    return isnearby
end

local function isinfront(spos, sdir, tpos)
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

function script.pileupwarning(dt)
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
            local distancefromme = car.position:distance(mycar.position)
            local infront, dirtot, returnval = isinfront(mycar.position,mycar.compass,car.position)
            if pileupsettings.debug then
                ui.bulletText('car: '..i..' - Km/h: '..math.floor(car.speedKmh)..' - Dir to car: '..math.floor(dirtot)..' - returnval: '..math.floor(returnval)..' - infront: '..tostring(infront)..' - Distance: '..math.floor(distancefromme))
            end
            if infront and car.speedKmh <= pileupsettings.minspeed and distancefromme >= pileupsettings.mindist and distancefromme <= pileupsettings.maxdist then
                if pileupsettings.debug then ui.sameLine(0,5) ui.text(' - (triggered)') end

                num = num+1
                local check = num
                if pileupsettings.playernearby then
                    if checkIsPlayerNearby(car.position) then
                        check = check + 1
                    end
                end
                if check >= pileupsettings.mincars then
                    showwarning = true
                    break
                end
            end
        end
    end
    if showwarning then
        ui.image('pileup.png',vec2(pileupsettings.signsize,pileupsettings.signsize))
    end
end

function script.pileupwarningMain(dt)
    ui.separator()
    pileupsettings.minspeed = ui.slider('Min speed', pileupsettings.minspeed, 0, 200, '%.0fKmh')
    if ui.itemHovered() then ui.setTooltip('Speeds above this can not trigger the warning') end
    pileupsettings.mindist = ui.slider('Min distance', pileupsettings.mindist, 0, pileupsettings.maxdist-1, '%.0fm')
    if ui.itemHovered() then ui.setTooltip('Distance below this can not trigger the warning') end
    pileupsettings.maxdist = ui.slider('Max distance', pileupsettings.maxdist, pileupsettings.mindist+1, 10000, '%.0fm')
    if ui.itemHovered() then ui.setTooltip('Distance above this can not trigger the warning') end
    pileupsettings.angle = ui.slider('Angle', pileupsettings.angle, 0, 180, '%.1f')
    if ui.itemHovered() then ui.setTooltip('Angles around the cars gps direction (both sides), where ai can trigger the warning') end
    pileupsettings.mincars = ui.slider('Min cars', pileupsettings.mincars, 1, 100, '%.0f')
    if ui.itemHovered() then ui.setTooltip('Minimum amount of cars to be triggered, before the warning will be triggered') end
    if ui.checkbox('Check for player', pileupsettings.playernearby) then
        pileupsettings.playernearby = not pileupsettings.playernearby
    end
    if ui.itemHovered() then ui.setTooltip('Will reduce min cars by one if a player is nearby') end
    if pileupsettings.playernearby then
        ui.sameLine(0,5)
        if ui.checkbox('Include yourself', pileupsettings.includeself) then
            pileupsettings.includeself = not pileupsettings.includeself
        end
        pileupsettings.playermaxdist = ui.slider('Player distance', pileupsettings.playermaxdist, 0, 1000, '%.0fm')
        if ui.itemHovered() then ui.setTooltip('Maximum distance to a nearby player to reduce') end
    end
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
            ['cam compass: '] = math.floor(ac.getCompassAngle(ac.getCameraForward()))
        }
        for key, value in pairs(t) do
            ui.bulletText(key..value)
        end
    end

    ui.labelText('','* pileupwarning by Halvhjearne!')
end

--function script.update(dt)
--    ac.setMessage('test','test test')
--end
