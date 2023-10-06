local args = {...}
local lazy = false

local station = {
    x = -4721,
    y = 69,
    z = -825,
    f = "east"
}

local coords = {
    x = station.x,
    y = station.y,
    z = station.z,
    f = station.f,
}

local begin = {
    x = -4720,
    y = 69,
    z = -832,
    f = station.f
}

local left = {
    ["north"] = "west",
    ["east"] = "north",
    ["south"] = "east",
    ["west"] = "south"
}

local right = {
    ["north"] = "east",
    ["east"] = "south",
    ["south"] = "west",
    ["west"] = "north"
}

local directions = {
    ["north"] = 1,
    ["east"] = 2,
    ["south"] = 3,
    ["west"] = 4,
    ["up"] = 5,
    ["down"] = 6,
    ["right"] = 7,
    ["left"] = 8,
    ["front"] = 9,
    ["back"] = 10
}

local stop = false

local function copyTable(original)
    local copy = {}
    for key, value in pairs(original) do
      if type(value) == "table" then
        value = copyTable(value)
      end
      copy[key] = value
    end
    return copy
  end  

local function dumpTable(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dumpTable(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

local function getFace(direction)
    direction = direction or coords.f
    if directions[direction] <= 6 then return direction end
    if direction == "right" then return right[coords.f] end
    if direction == "left" then return left[coords.f] end
    if direction == "front" then return coords.f end
    if direction == "back" then return right[right[coords.f]] end
end

local function faceTo(face)
    face = getFace(face)
    if face == coords.f then return end
    if directions[face] > 4 then return end
    if (directions[coords.f] + 3) % 4 == directions[face] then
        turtle.turnLeft()
        coords.f = left[coords.f]
    else
        while coords.f ~= face do
            turtle.turnRight()
            coords.f = right[coords.f]
        end
    end
end

local function updatePosition(length, face)
    if stop then return end
    length = length or 1
    local update = {
        ["north"] = function() coords.z = coords.z - length end,
        ["east"] = function() coords.x = coords.x + length end,
        ["south"] = function() coords.z = coords.z + length end,
        ["west"] = function() coords.x = coords.x - length end,
        ["up"] = function() coords.y = coords.y + length end,
        ["down"] = function() coords.y = coords.y - length end
    }
    update[getFace(face)]()
end

local function move(length, direction, dig)
    if stop then return end
    length = length or 1
    if dig == nil then dig = true end
    local face = getFace(direction)
    faceTo(face)
    local moving = {
        ["up"] = function() return turtle.up end,
        ["down"] = function() return turtle.down end
    }
    moving = (moving[face] or function() return turtle.forward end)()
    local digging = {
        ["up"] = function() return turtle.digUp end,
        ["down"] = function() return turtle.digDown end
    }
    digging = (digging[face] or function() return turtle.dig end)()
    local i = 1
    while length < 0 or i <= length  do
        local stuck = not moving()
        while stuck and dig do
            if not digging() then
                stop = true
                break
            end
            stuck = not moving()
        end
        if length < 0 and stuck then break end
        updatePosition(1, face)
        i = i + 1
    end
end

local function goTo(x, y, z, dig)
    if stop then return end
    if coords.y > y then
        move(coords.y - y, "down", dig)
    elseif coords.y < y then
        move(y - coords.y, "up", dig)
    end
    if coords.x > x then
        move(coords.x - x, "west", dig)
    elseif coords.x < x then
        move(x - coords.x, "east", dig)
    end
    if coords.z > z then
        move(coords.z - z, "north", dig)
    elseif coords.z < z then
        move(z - coords.z, "south", dig)
    end
end

local function goToStation()
    goTo(station.x, station.y, station.z)
    faceTo(station.f)
end

local function getSpaceAvailable()
    local sum = 0
    for i = 1, 16 do
        sum = sum + turtle.getItemSpace(i)
    end
    return sum
end

local function hasFreeSlot()
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then
            return true
        end
    end
    return false
end

local function inspect(face)
    face = getFace(face)
    local insp = turtle.inspect
    if face == "up" then insp = turtle.inspectUp end
    if face == "down" then insp = turtle.inspectDown end
    faceTo(face)
    local success, block = insp()
    return success and block or nil
end

local function dump(startSlot)
	startSlot = startSlot or 1
    local back = {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        f = coords.f
    }
    goToStation()
    faceTo("back")
    for i = startSlot, 16 do
        turtle.select(i)
        turtle.drop()
    end
	faceTo("back")
    turtle.select(1)
	turtle.suckUp()
	turtle.refuel()
	turtle.dropUp()
    goTo(back.x, back.y, back.z)
    faceTo(back.f)
end

------------------------------------------

local function run(lengthX, lengthZ)
    while true do
        for z = 1, lengthZ do
            for x = 1, lengthX - 1 do
                if not hasFreeSlot() then
                    dump()
                end
                move()
            end
            if z ~= lengthZ then
                if z % 2 == 1 then
                    move(1, "right")
                    move(0, "right")
                else
                    move(1, "left")
                    move(0, "left")
                end
            end
        end
        if stop then
            print("Stuck at " .. dumpTable(coords))
            stop = false
            goToStation()
            return
        end
        move(lengthZ - 1, "right")
        move(0, "right")
        move(1, "down")
    end
end

move(1)
goTo(begin.x, begin.y, begin.z)
move(-1, "down", false)
move(1, "down")
faceTo(begin.f)
run(tonumber(args[1]), tonumber(args[2]))
dump()