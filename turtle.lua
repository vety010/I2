while true do
     if turtle.getFuelLevel() == 0 then
          local didRefuel = false

          for i = 0, 3 do
               local slot = 16 - i
               local count = turtle.getItemCount(slot)

               if count ~= 0 then
                    turtle.select(slot)

                    local refueled, reason = turtle.refuel(1)
                    if refueled then
                         print("Refueled from slot " .. slot)
                         didRefuel = true
                         break
                    end
               end
          end

          if not didRefuel then 
               print("No fuel left!")
               break 
          end
     end

     for i = 1, 12 do
          local count = turtle.getItemCount(i)

          if count ~= 0 then
               turtle.select(i)
               break
          end
     end

     if not turtle.detectDown() then
          print("No block underneath! Something fucked up!")
          break
     end

     local wasPlaced, wasPlacedReason = turtle.place();

     if not wasPlaced then
          print("Could not place block!")
          print(wasPlacedReason)
     end

     local didMove = turtle.back()

     if not didMove then
          turtle.turnRight()
          if not turtle.detect() then
               turtle.turnLeft()
               turtle.turnLeft()
          end
     end
end