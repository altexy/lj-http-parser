local http_parser = dofile('lj_http_parser.lua')
local ffi = require 'ffi'

--[[
from http_parser/README.md
Reading headers may be a tricky task if you read/parse headers partially.
Basically, you need to remember whether last header callback was field or value
and apply following logic:

    (on_header_field and on_header_value shortened to on_h_*)
     ------------------------ ------------ --------------------------------------------
    | State (prev. callback) | Callback   | Description/action                         |
     ------------------------ ------------ --------------------------------------------
    | nothing (first call)   | on_h_field | Allocate new buffer and copy callback data |
    |                        |            | into it                                    |
     ------------------------ ------------ --------------------------------------------
    | value                  | on_h_field | New header started.                        |
    |                        |            | Copy current name,value buffers to headers |
    |                        |            | list and allocate new buffer for new name  |
     ------------------------ ------------ --------------------------------------------
    | field                  | on_h_field | Previous name continues. Reallocate name   |
    |                        |            | buffer and append callback data to it      |
     ------------------------ ------------ --------------------------------------------
    | field                  | on_h_value | Value for current header started. Allocate |
    |                        |            | new buffer and copy callback data to it    |
     ------------------------ ------------ --------------------------------------------
    | value                  | on_h_value | Value continues. Reallocate value buffer   |
    |                        |            | and append callback data to it             |
     ------------------------ ------------ --------------------------------------------
]]--

local headers_as_table
do
  local state_field = 1
  local state_value = 2
  headers_as_table = function(parser)
    local t = {}
    if parser.first == nil then
      return t
    end
    local entry = parser.first
    local cur_header, cur_value
    --print("first call")
    cur_header = ffi.string(entry[0].value.data, entry[0].value.size)
    local state = state_field -- should be
    entry = entry[0].next
    while entry ~= nil do
      local cur_data = ffi.string(entry[0].value.data, entry[0].value.size)
      if state == state_value then
        if entry[0].type == state_value then
          -- print"Value continues"
          if type(cur_value) == "table" then
            cur_value[#cur_value + 1] = cur_data
          else
            cur_value = { cur_value, cur_data }
          end
        else
          -- print"New header started, save header/value"
          if type(cur_value) == "table" then
            -- usually isn't the case, so not in fast path
            cur_value = table.concat(cur_value)
          end
          if type(cur_header) == "table" then
            -- usually isn't the case, so not in fast path
            cur_header = table.concat(cur_header)
          end
          -- TODO handle repeated header
          -- TODO too slow, LuaJit doesn't compile string.lower()
          -- t[string.lower(cur_header)] = cur_value
          t[cur_header] = cur_value
          cur_header = cur_data
        end
      else -- state == state_field
        if entry[0].type == state_value then
          --print"Value for current header started"
          cur_value = cur_data
        else
          --print"Previous name continues"
          if type(cur_header) == "table" then
            cur_header[#cur_header + 1] = cur_data
          else
            cur_header = { cur_header, cur_data }
          end
        end
      end
      state = entry[0].type
      entry = entry[0].next
    --print"loop end, save last value"
    end
    if type(cur_value) == "table" then
      -- usually isn't the case, so not in fast path
      cur_value = table.concat(cur_value)
    end
    if type(cur_header) == "table" then
      -- usually isn't the case, so not in fast path
      cur_header = table.concat(cur_header)
    end
    -- TODO handle repeated header
    -- TODO too slow, LuaJit doesn't compile string.lower()
    -- t[string.lower(cur_header)] = cur_value 
    t[cur_header] = cur_value
    return t
  end
end

local print_request_info = function(parser)
  print("url", ffi.string(parser.url.data, parser.url.size))
  print("http_major", parser.http_parser_.http_major)
  print("http_minor", parser.http_parser_.http_minor)
  local headers = headers_as_table(parser)
  for k, v in pairs(headers) do
    print(k, ": ", v)
  end
end

local parser = http_parser.ljhp_create_request_parser()

local request1 = [[
GET /forums/1/topics/2375?page=1#posts-17408 HTTP/1.1
User-Agent: curl/7.18.0 (i486-pc-linux-gnu) libcurl/7.18.0 OpenSSL/0.9.8g zlib/1.2.3.3 libidn/1.1
Host: 0.0.0.0=5000
Accept: */*

]]

local processed = http_parser.ljhp_http_parser_execute(parser, request1, #request1);
assert(processed == #request1)
print(processed)
print_request_info(parser)
http_parser.ljhp_http_parser_reset(parser)


local break_in_header_name = [[
GET /forums/1/topics/2375?page=1#posts-17408 HTTP/1.1
User-Ag]]

local break_in_header_name_2 = [[
ent: curl/7.18.0 (i486-pc-linux-gnu) libcurl/7.18.0 OpenSSL/0.9.8g zlib/1.2.3.3 libidn/1.1
Host: 0.0.0.0=5000
Accept: */*

]]

processed = http_parser.ljhp_http_parser_execute(parser, break_in_header_name, #break_in_header_name);
print(processed)
processed = http_parser.ljhp_http_parser_execute(parser, break_in_header_name_2, #break_in_header_name_2);
print(processed)
assert(parser.message_complete)
print_request_info(parser)
http_parser.ljhp_http_parser_reset(parser)

local break_in_header_value = [[
GET /forums/1/topics/2375?page=1#posts-17408 HTTP/1.1
User-Agent: curl/7.18.0 (i486-pc-]]

local break_in_header_value_2 = [[
linux-gnu) libcurl/7.18.0 OpenSSL/0.9.8g zlib/1.2.3.3 libidn/1.1
Host: 0.0.0.0=5000
Accept: */*

]]

processed = http_parser.ljhp_http_parser_execute(parser, break_in_header_value, #break_in_header_value);
print(processed)
processed = http_parser.ljhp_http_parser_execute(parser, break_in_header_value_2, #break_in_header_value_2);
print(processed)
assert(parser.message_complete)
print_request_info(parser)
http_parser.ljhp_http_parser_reset(parser)

local parser = http_parser.ljhp_create_request_parser()

-- loop should force luajit to compile
for i = 1, 1000000 do
  processed = http_parser.ljhp_http_parser_execute(parser, request1, #request1);
  local headers = headers_as_table(parser)
  http_parser.ljhp_http_parser_reset(parser)
  if i % 10 == 0 then
    processed = http_parser.ljhp_http_parser_execute(parser, break_in_header_name, #break_in_header_name);
    processed = http_parser.ljhp_http_parser_execute(parser, break_in_header_name_2, #break_in_header_name_2);
    local headers = headers_as_table(parser)
    http_parser.ljhp_http_parser_reset(parser)
  end
  http_parser.ljhp_http_parser_reset(parser)
end

http_parser.ljhp_http_parser_destroy(parser)
