local args = {...}
local lazy = false

local station = {
    x = -4537,
    y = 71,
    z = -595,
    f = "south"
}

local coords = {
    x = station.x,
    y = station.y,
    z = station.z,
    f = station.f,
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
    dig = dig or true
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
    for i = 1, length do
        while not moving() and dig do
            if not digging() then
                stop = true
                break
            end
        end
        updatePosition(1, face)
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
    faceTo("back")
    for i = startSlot, 16 do
        turtle.select(i)
        turtle.drop()
    end
	faceTo("back")
end

--------------------------------------------------------------

local function isLeave(block)
    if block == nil or block.tags == nil then return end
    for k, v in pairs(block.tags) do
        if string.find(k, "leaves") then
            return true
        end
    end
end

local function isWood(block)
    return block ~= nil and block.name == "minecraft:oak_log"
end

local function isAir(block)
	return block ~= nil and block.name == nil
end

local function cutTree(deep)
    deep = deep or 1
    print("enter: " .. deep)
    local function cut(face)
        local back = copyTable(coords)
        move(1, face)
        cutTree(deep + 1)
        goTo(back.x, back.y, back.z)
		faceTo(back.f)
        print("leave: " .. deep)
    end
    local leaves = {}
    local woodFound = false
    local back = copyTable(coords)
    for _, direction in ipairs((lazy and deep ~= 1) and {"up"} or {"front", "right", "right", "right", "up", "down"}) do
        local face = getFace(direction)
        local block = inspect(face)
        if isWood(block) then
            cut(face)
            woodFound = true
        elseif not lazy and isLeave(block) then
            table.insert(leaves, face)
        end
    end
    if not lazy and not woodFound then
        for _, face in pairs(leaves) do
            if isLeave(inspect(face)) then
                cut(face)
            end
        end
    end
    faceTo(back.f)
end

local function farmTree(deep)
    deep = deep or 1
    print("enter: " .. deep)
    local function cut(face)
        local back = copyTable(coords)
        move(1, face)
        farmTree(deep + 1)
        goTo(back.x, back.y, back.z)
		faceTo(back.f)
        print("leave: " .. deep)
    end
    local back = copyTable(coords)
    for _, direction in ipairs(deep ~= 1 and {"up"} or {"right", "back"}) do
        local face = getFace(direction)
        local block = inspect(face)
        if isWood(block) then
            cut(face)
		end
		if deep == 1 and (isWood(block) or isAir(block)) then turtle.place() end
    end
    faceTo(back.f)
end

local function farm(rows)
	rows = rows / 2
	while true do
		move(4)
		for z = 1, rows do
			for x = 1, 6 do
				farmTree()
				if x ~= 6 then
					move(2)
				end
			end
			move(1)
			if z % 2 == 1 and z ~= rows then
				move(4, "right")
				move(1, "right")
			elseif z ~= rows then
				move(4, "left")
				move(1, "left")
			end
		end
		goToStation()
		dump(2)
		turtle.select(1)
		turtle.suckDown(turtle.getItemSpace())
		turtle.select(2)
		turtle.suckUp()
		turtle.refuel()
		turtle.dropUp()
		turtle.select(1)
	end
end

if #args > 0 then
    if args[1] == "farm" then
        lazy = true
        farm(16)
    elseif args[1] == "test" then
        local _, block = turtle.inspect()
        for k, v in pairs(block.tags) do
            if string.find(k, "leaves") then
                print(k)
            end
        end
    end
end
if #args == 0 then
    cutTree()
    faceTo(station.f)
end