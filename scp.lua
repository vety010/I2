-- TODO: this should check all directories by default
os.loadAPI("/disk/cli")
os.loadAPI("/disk/events")

local monitor = peripheral.find("monitor")

local probe_1 = peripheral.wrap("ElnProbe_0")
probe_1.signalSetDir("XP", "in") -- Defences temporary off
probe_1.signalSetDir("XN", "out") -- Disable defences

local probe_2 = peripheral.wrap("ElnProbe_1")
probe_2.signalSetDir("XN", "in") -- Site power state

local lockdownMessages = {
     "--- LOCKDOWN ---",
     "DEFENCES ACTIVE"
}

local perMessageTicks = 20
local ticks = 0
local messageI = 1

local lastPowerState = false

function onTick()
     monitor.clear()

     monitor.setTextScale(1.5)
     local width, height = monitor.getSize()

     local function centerForText(text, y)
          local x = math.floor((width - #text) / 2) + 1

          monitor.setCursorPos(x, y)
     end

     -- Writes centered text
     local function writeCentered(text, y)
          centerForText(text, y)
          monitor.write(text)
     end

     monitor.setTextColor(colors.white)
     centerForText("SCP - GATE B [LCZ]", 1)
     monitor.write("SCP - GATE ")
     monitor.setTextColor(colors.red)
     monitor.write("B ")
     monitor.setTextColor(colors.white)
     monitor.write("[")
     monitor.setTextColor(colors.gray)
     monitor.write("LCZ")
     monitor.setTextColor(colors.white)
     monitor.write("]")

     local defencesTemporaryOff = probe_1.signalGetIn("XP") > 0.5
     local powerValue = probe_2.signalGetIn("XN")
     local powerState = 
          powerValue > 0.9117 and "ok" or 
          powerValue > 0.88 and "unstable" or 
          powerValue > 0.85 and "critical" or
          "off"
     
     if powerState ~= lastPowerState then
          cli.set("power state", powerState)
          
          lastPowerState = powerState
     end
     
     local defencesState = true -- on

     if powerState == "off" then
          monitor.setTextColor(colors.red)
          writeCentered("SITE POWER OFF", 2)
          writeCentered("!! EMERGENCY !!", 3)
     elseif powerState == "critical" then
          monitor.setTextColor(colors.red)
          writeCentered("SITE POWER IS", 2)
          writeCentered("CRITICALLY LOW", 3)
     elseif defencesTemporaryOff then
          monitor.setTextColor(colors.green)
          writeCentered("DEFENCES ARE OFF", 2)
          writeCentered("PROCEED QUICKLY", 3)

          defencesState = false
     else
          local isBreach = cli.get("breach active")
          local isLockdown = isBreach or cli.get("lockdown active")
          
          if isLockdown and isBreach then
               -- Lockdown text
               monitor.setTextColor(colors.red)
               writeCentered(lockdownMessages[messageI], 2)
               -- Breach text
               monitor.setTextColor(colors.red)
               writeCentered("BREACH DETECTED", 3)
          elseif isLockdown then
               monitor.setTextColor(colors.red)
               for i = 1, 2 do
                    writeCentered(lockdownMessages[i], i + 1)
               end
          else
               if powerState == "unstable" then
                    monitor.setTextColor(colors.orange)
                    writeCentered("Unstable power!", 2)
                    writeCentered("Please fix!", 3)
               else
                    monitor.setTextColor(colors.green)
                    writeCentered("Welcome!", 2)
                    writeCentered("Defences offline", 3)
               end
               
               defencesState = false
          end
     end

     if defencesState then
          probe_1.signalSetOut("XN", 0)
     else
          probe_1.signalSetOut("XN", 1)
     end

     ticks = ticks + 1
     if ticks > perMessageTicks then
          messageI = messageI + 1
          if messageI > #lockdownMessages then
               messageI = 1
          end
          ticks = 0
     end
end

hook.add("tick", "renderer", onTick)
events.startThinking()