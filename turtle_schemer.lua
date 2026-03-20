-- CFG
local blocks = {
     "bricks",
     "concrete",
     "metal sheet",
     "steel sheet",
     "soapstone bricks",
}

blocks[0] = "air"

local scheme = {
     {0, 1, 2, 2, 3, 3, 2, 2, 1, 0},
     {1, 2, 0, 0, 0, 0, 0, 0, 2, 1},
     {2, 0, 0, 0, 0, 0, 0, 0, 0, 2},
     {2, 0, 0, 0, 0, 0, 0, 0, 0, 2},
     {3, 0, 0, 4, 0, 0, 4, 0, 0, 3},
     {1, 2, 2, 1, 0, 0, 1, 2, 2, 1},
     {5, 0, 0, 0, 0, 0, 0, 0, 0, 5},
     {1, 5, 0, 0, 0, 0, 0, 0, 5, 1},
     {0, 1, 5, 5, 5, 5, 5, 5, 1, 0},
}

-- * Slot 16 is ALWAYS fuel
local inventoryScheme = {
     1, 1, 1, 1,
     2, 2, 2, 2,
     5, 5, 5, 5,
     3, 3, 4, 0,
}

-- CODE
local pos = {
     x = 1,
     z = 1,

     facingX = 1,
     needToAdvance = false
}

-- Calculating cost for one layer
local blockCounts = {}
for x, row in pairs(scheme) do
     for y, block in pairs(row) do
          blockCounts[block] = (blockCounts[block] or 0) + 1
     end
end

-- Prints costs for one layer
function printLayerCost()
     local current = getMaterialsCount()

     print("Per-layer costs:")
     for block, amount in pairs(blockCounts) do
          print("[" .. block .. "] " .. blocks[block] .. ": " .. amount .. " pcs. (" .. (current[block] or 0) .. ")")
     end
end

-- Returns how much of what material we have based on inventoryScheme
function getMaterialsCount()
     local result = {}

     result[0] = math.huge -- Assume infinite air

     for slot, block in pairs(inventoryScheme) do
          if block ~= 0 then
               result[block] = (result[block] or 0) + turtle.getItemCount(slot)
          end
     end

     return result
end

-- How many layers can we do with current config
-- * returns layers count and how much resources are needed to get that count to one more
function getAffordableLayersCount()
     local current = getMaterialsCount()
     local required = blockCounts -- fancy alias, ok?
     local forAnotherLayer = {}
     
     local affordableLayers = 5000

     for block, amountRequired in pairs(required) do
          local amountCurrent = current[block] or 0
          local sufficientFor = math.floor(amountCurrent / amountRequired)
          
          affordableLayers = math.min(affordableLayers, sufficientFor)
     end
     
     for block, amountRequired in pairs(required) do
          local amountCurrent = current[block] or 0
          local leftovers = amountCurrent - amountRequired * affordableLayers

          if leftovers > amountRequired then leftovers = amountRequired end

          forAnotherLayer[block] = amountRequired - leftovers
     end

     return affordableLayers, forAnotherLayer
end

function moveCommand(cmd, noUpdatePos)
     local result, reason = turtle[cmd]()

     if result then
          if noUpdatePos then return true end

          -- Starting from topleft corner, facing inside the tunnel, facing AWAY from center
          if cmd == "forward" then
               pos.x = pos.x - pos.facingX
          elseif cmd == "back" then
               pos.x = pos.x + pos.facingX
          elseif cmd == "up" then
               pos.z = pos.z - 1
          elseif cmd == "down" then
               pos.z = pos.z + 1
          end
     else
          print("Moving failed! Retrying in 3s...")
          os.sleep(3)
          refuel()
     end

     return result
end

-- Function we call on layer start
function layerStart()
     printLayerCost()
     
     local canAfford, required = getAffordableLayersCount()

     if canAfford == 0 then
          print("Insufficient materials to start a layer! Retrying in 5 seconds...")
          print("Lacking:")
          
          for block, amount in pairs(required) do
               if amount ~= 0 then print("[" .. block .. "] " .. blocks[block] .. ": " .. amount) end
          end

          os.sleep(5)
          return false
     else
          print("Sufficient materials for "..canAfford.." layers.")
          return true
     end
end

-- Refuelling handler
function refuel()
     if turtle.getFuelLevel() > 0 then return false end

     local slot = 16
     local count = turtle.getItemCount(slot)

     if count ~= 0 then
          turtle.select(slot)

          local refueled, reason = turtle.refuel(1)
          if refueled then
               print("Refueled from slot " .. slot)
               print("New fuel level: "..turtle.getFuelLevel().."/"..turtle.getFuelLimit())
               return false
          else
               print("Failed to refuel!")
               os.sleep(1)
               return true
          end
     else
          print("Waiting for fuel load...")
          os.sleep(1)
          return true
     end
end

local isProcessingLayer = false

function tick()
     if refuel() then return end

     if isProcessingLayer then
          if scheme[pos.z] == nil then
               pos.needToAdvance = true

               isProcessingLayer = false
               print("Finished a layer! Who's a good boy?")
               os.sleep(3)

               return 
          end
               
          local block = scheme[pos.z][pos.x]

          if block == nil then
               -- Row shifting
               moveCommand("down")
               moveCommand("turnLeft")
               moveCommand("turnLeft")
               pos.facingX = pos.facingX * -1
               moveCommand("back")
          else
               if block ~= 0 then
                    -- Selecting the block
                    for slot, slotBlock in pairs(inventoryScheme) do
                         if block == slotBlock and turtle.getItemCount(slot) > 0 then
                              turtle.select(slot)
                              break
                         end
                    end
               end
     
               -- Moving to place the block
               if not moveCommand("back") then return end
     
               -- Placing the block
               if block ~= 0 then turtle.place() end
          end
     elseif pos.x == 1 and pos.z == 1 and pos.facingX == 1 and not pos.needToAdvance then
          isProcessingLayer = layerStart()
     elseif pos.facingX ~= 1 then
          moveCommand("turnLeft")
          moveCommand("turnLeft")
          pos.facingX = 1
     elseif pos.needToAdvance then
          -- Here we are already guaranteed to be facing the original direction
          moveCommand("turnLeft")
          moveCommand("forward", true)
          moveCommand("turnRight")
          pos.needToAdvance = false
     elseif pos.x ~= 1 then
          moveCommand((pos.x > 1) and "forward" or "back")
     elseif pos.z ~= 1 then
          moveCommand((pos.z > 1) and "up" or "down")
     end
end

-- TODO: some mislogic somewhere, bottom rows aren't placed (material requirements miscalculation?)
-- TODO: every second layer turtle should just do backwards instead of returning to the original position

while not tick() do end