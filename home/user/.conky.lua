function iface_list()
    local ret = {}
    f = io.open("/proc/net/dev")
    for l in f:lines() do
        ifname=string.match(l, '^ *([^:]+):')
        if ifname ~= nil then
            ret[#ret+1]=ifname
        end
    end
    f:close()
    return ret
end

function conky_gwifinfo()
    local ret = {}
    local gw_iface,gw_ip = conky_parse("$gw_iface $gw_ip"):match('^([^ ]+) (.*)$')
    for _,i in pairs(iface_list()) do
        local ip=conky_parse("${addrs "..i.."}")
        if ip ~= '0.0.0.0' and not (ip == '127.0.0.1' and i == 'lo') then
            ret_str = ip:gsub(',','\n')
            if i == gw_iface then
                ret_str = "${font :size=14}${color green}" .. ret_str .. "${color}${font}\n(via " .. gw_ip .. " dev " .. i .. ")"
            else
                ret_str = i .. ": " .. ret_str
            end
            ret[#ret+1] = ret_str
        end
    end
    if #ret == 0 then
        return "${color red}No public IP addresses${color}"
    end
    return table.concat(ret, "\n")
end
