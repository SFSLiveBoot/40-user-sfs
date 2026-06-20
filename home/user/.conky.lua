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

function conky_meminfo_bar()
    return 100*writeback/(dirty+writeback)
end

function format_size(v)
    return ((v>=1024*1024*1024) and string.format("%.1fGiB", v/(1024*1024*1024)) or ((v>=1024*1024) and string.format("%.1fMiB", v/(1024*1024))) or ((v>=1024 and string.format("%.1fKiB", v/1024))) or v.."B")
end

function conky_meminfo()
    local f = io.open("/proc/meminfo")
    for l in f:lines() do
        n, v = string.match(l, '^([^:]+):[ \t]*([0-9]+) kB$')
        if n == 'Dirty' then
            dirty = v
        elseif n=='Writeback' then
            writeback = v
        end
    end
    f:close()
    if ((dirty ~= nil or writeback ~= nil) and not (dirty == '0' and writeback == '0')) then
        return "\n${color grey}Dirty/Write${color} ".. format_size(dirty*1024) .. "/" .. format_size(writeback*1024)
    else
        return ""
    end
end

-- temperature

-- Read temps and names from /sys/class/thermal/thermal_zone*/{temp,type}
local function read_sys_temps()
  local temps = {}
  local i = 0
  while true do
    local base = string.format("/sys/class/thermal/thermal_zone%d", i)
    local ftemp = io.open(base .. "/temp", "r")
    if not ftemp then break end
    local val = ftemp:read("*all")
    ftemp:close()
    val = val and val:match("%-?%d+")
    local name = nil
    local ftype = io.open(base .. "/type", "r")
    if ftype then
      name = ftype:read("*all")
      ftype:close()
      if name then name = name:match("^%s*(.-)%s*$") end
    end
    local t = nil
    if val then
      t = tonumber(val)
      if t and math.abs(t) > 1000 then t = t / 1000 end
    end
    table.insert(temps, {zone = i, name = (name ~= "" and name) or nil, temp = t})
    i = i + 1
  end
  return temps
end

-- Fall back to parsing `sensors` command output (lm-sensors)
local function read_sensors_cmd()
  local temps = {}
  local handle = io.popen("sensors 2>/dev/null")
  if not handle then return temps end
  local out = handle:read("*all")
  handle:close()
  if out == "" then return temps end
  for label, val in out:gmatch("([%w%p ]-):%s*([%+%-]?%d+%.?%d*)°[Cc]") do
    local t = tonumber(val)
    if t then
      label = label:gsub("^%s+", ""):gsub("%s+$", "")
      table.insert(temps, {zone = label, name = label, temp = t})
    end
  end
  return temps
end

local is_cmd = false

-- Return a table of temperatures; prefer sysfs if available
local function get_temps()
  is_cmd = false
  local sys = read_sys_temps()
  if #sys > 0 then return sys end
  is_cmd = true
  return read_sensors_cmd()
end

-- Choose color tag based on temperature (Conky color tags: ${color name} ... ${color})
local function color_for_temp(t)
  if type(t) ~= "number" then
    return "${color #404040}"  -- unreadable
  end
  if t <= 30 then
    return "${color cyan}"
  elseif t <= 50 then
    return "${color green}"
  elseif t <= 70 then
    return "${color yellow}"
  elseif t <= 90 then
    return "${color red}"
  else
    return "${color magenta}"
  end
end

-- Reset color tag
local function color_reset()
  return "${color}" -- resets to default
end

-- Format: each sensor on its own row; show "cannot read" when temp is nil
-- Pad so all temperature values end at the same horizontal position
-- Wrap temperature text in Conky color tags
local function format_temps(temps)
  if #temps == 0 then return "No temperature data" end

  -- build label and temp strings, track max widths (exclude color tags from width)
  local rows = {}
  local max_label = 0
  local max_temp = 0
  for _, v in ipairs(temps) do
    local label = v.name or ("zone" .. tostring(v.zone))
    if #label > max_label then max_label = #label+1 end
    local tstr
    if type(v.temp) == "number" then
      tstr = string.format("%.1f°C", v.temp)
    else
      tstr = "unavailable"
    end
    if #tstr > max_temp then max_temp = #tstr end
    table.insert(rows, {label = label, tstr = tstr, temp = v.temp})
  end

  -- build lines with right-aligned temperature column and color tags
  local lines = {}
  for _, r in ipairs(rows) do
    local label_pad = r.label .. string.rep(" ", math.max(1, max_label - #r.label))
    local temp_pad = string.rep(" ", math.max(1, max_temp - #r.tstr))
    local col = color_for_temp(r.temp)
    local temp_text = col .. r.tstr .. color_reset()
    table.insert(lines, label_pad .. "  " .. temp_pad .. temp_text)
  end

  return table.concat(lines, "\n")
end

-- Conky Lua hook: returns string inserted into conky.text by ${lua var}
function conky_cpu_temp_text()
  local t = get_temps()
  return format_temps(t)
end

-- Expose function name used in conky.text: ${lua cpu_temp_text}
function cpu_temp_text()
  return conky_cpu_temp_text()
end
