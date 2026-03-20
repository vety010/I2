-- OWO.

--   ARP packet:
--        ARP|<TAG>|<MAC>|<IP?>         -- Updates opponent's ARP information. IP is optional. 
--                                      -- Tag is either I or R, which stand for INITIAL and REPLY respectively.
--   DHCP packet:
--        DHCP|GET                      -- Gets a lease from an upstream DHCP server
--        DHCP|IPSET|<IP>|<LEASETIME>   -- Upsteam DHCP server's response
     
     -- DHCP packet
     if channel == settings.DHCP_port and replyChannel == settings.DHCP_port and packetArr[1] == "DHCP" then
          -- A GET packet means a downstream device requests address
          if packetArr[2] == "GET" then
               local success, ip, leaseTime, reason = dhcp.getAddressFor(NIC.mac); 

               if not success then return print("[I2] DHCP lease failed: " .. reason) end
               
               -- Respond with the IP address given out by DHCP
               NIC.peripheral.transmit(settings.DHCP_port, settings.DHCP_port, "DHCP|IPSET|"..ip.."|"..leaseTime);

               return
          end

          -- An IPSET packet means an upstream device gave us an address (typically after GET request)
          if packetArr[2] == "IPSET" then
               local ip = packetArr[3]
               local leaseTime = tonumber(packetArr[4])

               print("[I2] DHCP lease received: "..ip..", expires in "..leaseTime.." seconds")

               NIC.address = ip
               NIC.addressExpires = os.clock() + leaseTime

               return
          end
     end

     function getPortForTraffic(trafficType)
     if trafficType == "message" then
          return math.random(1000, 10000)
     elseif staticTrafficTypes[trafficType] then
          return staticTrafficTypes[trafficType]
     end

     error("Unknown traffic type fetch attempt!")
end

settings = {
     -- Full filename of the file where MAC address is stored.
     MACAddressFilename = "/_mac_address",

     -- Port number to be used by DHCP
     DHCP_port = 67,
     -- Maximum DHCP client refresh rate, in seconds.
     DHCP_refreshRate = 3,

     upstream_ports = {
          "top",
          "bottom",
          "back",
          "front",
          "left",
          "right"
     },
}

dhcp = dhcp

-- Router object (if exists)
router = nil

os.loadAPI("/disk/net/base/dhcp")


-- Check if the port used exists in upstream ports dictionary.
     -- If so, mark port as upstream (connects to higher routers)
     for k, v in pairs(settings.upstream_ports) do
          if v == side then
               networkCards[side].isUpstream = true
               break
          end
     end

     -- Log NIC is up
     print("[I2] NIC UP at "..side.." ("..(NIC.isUpstream and "UPSTREAM" or "DOWNSTREAM")..")")

     -- Updating addresses on any NICs that have those expired
     local ctime = os.clock()
     for side, nic in pairs(networkCards) do
          if nic.isUpstream and nic.mac and ctime > nic.addressExpires then
               -- Maximum refresh rate
               nic.addressExpires = ctime + settings.DHCP_refreshRate
               -- Requesting an address
               nic.peripheral.transmit(settings.DHCP_port, settings.DHCP_port, "DHCP|GET")
          end
     end


     if not nextNIC then
          -- We do not need recursion here.
          if packetType == "E" then return end
          -- Return an error if the packet originated from us.
          if not NIC then return onPacket(nil, "E", destination, MAC, source, "DESTINATION_NET_UNREACHABLE") end
          -- Return error: we do not know where to forward a packet
          return onPacket(nil, "E", MAC, NIC.mac, source, "DESTINATION_HOST_UNREACHABLE")
     end


     -- Clearing leases if MAC exists
          if networkCards[v].mac then
               dhcp.NICDisconnect(networkCards[v].mac)
          end